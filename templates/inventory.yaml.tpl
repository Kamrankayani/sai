---
all:
  hosts:
    control-plane:
      ansible_host: ${control_plane_ip}
      ansible_user: ${ansible_user}
      ansible_ssh_private_key_file: ${ssh_key_path}
  children:
    control_plane:
      hosts:
        control-plane:
    workers:
      hosts:
%{ for ip in worker_ips ~}
        worker-${index(worker_ips, ip) + 1}:
          ansible_host: ${ip}
          ansible_user: ${ansible_user}
          ansible_ssh_private_key_file: ${ssh_key_path}
%{ endfor ~}
  vars:
    ansible_python_interpreter: /usr/bin/python3
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'