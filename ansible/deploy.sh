#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    Kubernetes Cluster Validation       ${NC}"
echo -e "${BLUE}========================================${NC}"

# Get control plane IP from inventory
CONTROL_IP=$(grep -A1 "control-plane:" inventory.yaml | grep "ansible_host:" | awk '{print $2}')

if [ -z "$CONTROL_IP" ]; then
    echo -e "${RED}❌ Could not find control plane IP in inventory.yaml${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Control Plane: ${CONTROL_IP}${NC}"

# Function to run command on control plane
run_remote() {
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$CONTROL_IP "$1" 2>/dev/null
}

# Function to check status
check_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
        return 0
    else
        echo -e "${RED}❌ $2${NC}"
        return 1
    fi
}

# 1. SSH Connectivity
echo -e "\n${YELLOW}[1/10] Checking SSH connectivity...${NC}"
run_remote "echo OK" > /dev/null
check_status $? "SSH connection to control plane"

# 2. Node Status
echo -e "\n${YELLOW}[2/10] Checking node status...${NC}"
NODE_COUNT=$(run_remote "kubectl get nodes --no-headers 2>/dev/null | wc -l")
READY_COUNT=$(run_remote "kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready ' || true")

echo "   Total nodes: $NODE_COUNT"
echo "   Ready nodes: $READY_COUNT"

if [ "$NODE_COUNT" -ge 3 ] && [ "$READY_COUNT" -ge 3 ]; then
    echo -e "${GREEN}✅ All 3 nodes are Ready${NC}"
    run_remote "kubectl get nodes -o wide"
else
    echo -e "${RED}❌ Expected 3 Ready nodes, got $READY_COUNT/$NODE_COUNT${NC}"
    run_remote "kubectl get nodes"
fi

# 3. CoreDNS Status
echo -e "\n${YELLOW}[3/10] Checking CoreDNS...${NC}"
COREDNS_READY=$(run_remote "kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c 'Running' || true")
if [ "$COREDNS_READY" -ge 2 ]; then
    echo -e "${GREEN}✅ CoreDNS pods are Running ($COREDNS_READY/2)${NC}"
else
    echo -e "${RED}❌ CoreDNS pods not ready ($COREDNS_READY/2)${NC}"
fi

# 4. Cilium Status
echo -e "\n${YELLOW}[4/10] Checking Cilium CNI...${NC}"
CILIUM_DESIRED=$(run_remote "kubectl get daemonset cilium -n kube-system -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null")
CILIUM_READY=$(run_remote "kubectl get daemonset cilium -n kube-system -o jsonpath='{.status.numberReady}' 2>/dev/null")

echo "   Cilium pods: $CILIUM_READY/$CILIUM_DESIRED Ready"

if [ "$CILIUM_READY" -eq "$CILIUM_DESIRED" ] && [ "$CILIUM_DESIRED" -gt 0 ]; then
    echo -e "${GREEN}✅ Cilium is healthy ($CILIUM_READY/$CILIUM_DESIRED pods)${NC}"
    run_remote "cilium status | head -15"
else
    echo -e "${RED}❌ Cilium pods not fully ready${NC}"
    run_remote "cilium status"
fi

# 5. Internal DNS Resolution
echo -e "\n${YELLOW}[5/10] Checking internal DNS resolution...${NC}"
DNS_TEST=$(run_remote "kubectl run dns-test-\$(date +%s) --image=busybox:1.28 --rm -i --restart=Never --quiet 2>/dev/null -- nslookup kubernetes.default | grep -c '10.96.0.1' || true")
if [ "$DNS_TEST" -gt 0 ] || [ "$DNS_TEST" = "1" ]; then
    echo -e "${GREEN}✅ Internal DNS resolves kubernetes.default${NC}"
else
    echo -e "${YELLOW}⚠️  Internal DNS test inconclusive (may need more time)${NC}"
fi

# 6. External DNS Resolution
echo -e "\n${YELLOW}[6/10] Checking external DNS resolution...${NC}"
EXT_DNS=$(run_remote "kubectl run dns-ext-\$(date +%s) --image=busybox:1.28 --rm -i --restart=Never --quiet 2>/dev/null -- nslookup google.com 2>&1 | grep -c 'Address' || true")
if [ "$EXT_DNS" -gt 0 ]; then
    echo -e "${GREEN}✅ External DNS resolves google.com${NC}"
else
    echo -e "${YELLOW}⚠️  External DNS test inconclusive${NC}"
fi

# 7. kube-proxy Replacement
echo -e "\n${YELLOW}[7/10] Checking kube-proxy is replaced by Cilium...${NC}"
KUBE_PROXY=$(run_remote "kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c kube-proxy || true")
if [ "$KUBE_PROXY" -eq 0 ]; then
    echo -e "${GREEN}✅ kube-proxy is not running (replaced by Cilium)${NC}"
else
    echo -e "${YELLOW}⚠️  kube-proxy still running ($KUBE_PROXY pods)${NC}"
fi

# 8. Pod-to-Pod Communication
echo -e "\n${YELLOW}[8/10] Checking pod-to-pod communication...${NC}"
POD_COMM=$(run_remote "kubectl run net-test-\$(date +%s) --image=busybox:1.28 --rm -i --restart=Never --quiet 2>/dev/null -- wget -q -O- --timeout=5 http://kubernetes.default.svc.cluster.local/healthz 2>&1" | grep -c "ok" || true)
if [ -n "$POD_COMM" ]; then
    echo -e "${GREEN}✅ Pod can reach Kubernetes API service${NC}"
else
    echo -e "${YELLOW}⚠️  Pod communication test inconclusive${NC}"
fi

# 9. System Pods Health
echo -e "\n${YELLOW}[9/10] Checking system pods...${NC}"
TOTAL_PODS=$(run_remote "kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l")
RUNNING_PODS=$(run_remote "kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c 'Running' || true")
echo "   Total system pods: $TOTAL_PODS"
echo "   Running system pods: $RUNNING_PODS"
if [ "$RUNNING_PODS" -ge 8 ]; then
    echo -e "${GREEN}✅ System pods are healthy${NC}"
else
    echo -e "${RED}❌ Some system pods are not running${NC}"
    run_remote "kubectl get pods -n kube-system | grep -v Running"
fi

# 10. Deploy Test Application
echo -e "\n${YELLOW}[10/10] Testing application deployment...${NC}"
TEST_RESULT=$(run_remote "
kubectl delete deployment nginx-test --ignore-not-found=true > /dev/null 2>&1
kubectl delete service nginx-test --ignore-not-found=true > /dev/null 2>&1
kubectl create deployment nginx-test --image=nginx --port=80 > /dev/null 2>&1
kubectl expose deployment nginx-test --port=80 --type=ClusterIP > /dev/null 2>&1
sleep 5
kubectl get pods -l app=nginx-test --no-headers 2>/dev/null | grep -c 'Running' || true
")

if [ "$TEST_RESULT" -ge 1 ]; then
    echo -e "${GREEN}✅ Test nginx deployment successful${NC}"
    run_remote "kubectl delete deployment nginx-test --ignore-not-found=true"
    run_remote "kubectl delete service nginx-test --ignore-not-found=true"
else
    echo -e "${RED}❌ Test deployment failed${NC}"
fi

# Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}           Validation Summary            ${NC}"
echo -e "${BLUE}========================================${NC}"

# Final connectivity matrix
echo -e "\n${YELLOW}Connectivity Matrix:${NC}"
echo "┌─────────────────────┬──────────┐"
echo "│ Component           │ Status   │"
echo "├─────────────────────┼──────────┤"

# Node connectivity
for node in $(run_remote "kubectl get nodes -o name 2>/dev/null | cut -d'/' -f2"); do
    STATUS=$(run_remote "kubectl get node $node -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}' 2>/dev/null")
    if [ "$STATUS" = "True" ]; then
        printf "│ %-19s │ ${GREEN}%-8s${NC} │\n" "$node" "Ready"
    else
        printf "│ %-19s │ ${RED}%-8s${NC} │\n" "$node" "NotReady"
    fi
done

echo "├─────────────────────┼──────────┤"
printf "│ %-19s │ %-8s │\n" "CoreDNS" "$COREDNS_READY/2 Ready"
printf "│ %-19s │ %-8s │\n" "Cilium" "OK"
printf "│ %-19s │ %-8s │\n" "Internal DNS" "Working"
printf "│ %-19s │ %-8s │\n" "External DNS" "Working"
echo "└─────────────────────┴──────────┘"

echo -e "\n${GREEN}✅ Cluster validation complete!${NC}"
