'''
Author: Gabriele Saronni
From a csv file reads the IPs and outputs the needed configuration
20220818: add try catch
20230523: Added Jinja2 and CLI pasting
20241031: Refined file output and identify wrong IPs
'''

import os
import sys
import ipaddress
from datetime import datetime
from jinja2 import Template

config_template = Template("""changeto context DMZ
!
configure terminal
!
object-group network {{ group_name }}
!
{% for ip in ips %}
network-object host {{ ip }}\n!
{% endfor %}
exit
!
object-group network IP_DENY_container
!
group-object {{ group_name }}
!
show object-group id {{ group_name }}
!
show object-group id IP_DENY_container | i {{ group_name }}
!
write memory
!""")

def validate_ips(ips):
  valid_ips = []
  invalid_ips = []
  for ip in ips:
    ip = ip.replace("[.]", ".")  # Replace '[.]' with '.'
    try:
      valid_ips.append(ipaddress.ip_address(ip))
    except ValueError:
      invalid_ips.append(ip)
  return valid_ips, invalid_ips

def build_config(ips, group_name):
  return config_template.render(ips=ips, group_name=group_name)

def write_config_to_file(filename, config):
  with open(filename, "w") as f:
      f.write(config)

def read_config_from_file(filename):
  with open(filename, "r") as f:
    return f.read()

def main():
  ips = set()  # Use a set to avoid duplicate IPs
  print("Enter the IP addresses (use an empty line to finish):")
  while True:
    ip = input()
    if not ip:
      break
    ips.add(ip)

  if not ips:
    print("No IP addresses provided.")
    return

  valid_ips, invalid_ips = validate_ips(ips)

  if invalid_ips:
    print("The following IP addresses are not valid:")
    for ip in invalid_ips:
      print(f" - {ip}")

  now = datetime.now()
  group_name = now.strftime("CNG_%d_%m_%Y")

  # Determine the username and set the file path accordingly
  username = os.environ.get('USERNAME') # Get the current user's login name
  if username.lower() == "myUserName":
    directory = rf"C:\Users\{username}\root\wShp\asaFirePowerActivities\ipBlock\archive"
  else:
    directory = rf"C:\Users\{username}\Documents\ipBlockLog"

  # Create the directory if it doesn't exist
  os.makedirs(directory, exist_ok=True)

  filename = os.path.join(directory, now.strftime("%Y%m%d_%H%M%S.ios"))

  if valid_ips:
    config = build_config(valid_ips, group_name)
    write_config_to_file(filename, config)
    print(f"Configuration written to file: {filename}")
    print(read_config_from_file(filename))

if __name__ == "__main__":
    main()
