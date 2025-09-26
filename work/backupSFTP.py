'''
Author: Gabriele Saronni
- 20220405 v1
- 20230120 v4.7
  - Autodiscover username
  - fixed MI-VMX900 with new module send_command_timing
- 20230626 v4.8
  - Catch ctrl+c exception
  - Discovered MI-VMX900-1, MI-VSX909-10 stopped fetching conf
  - Fixed MI-VMX900-1
- 20230714 v4.9
  - Dropped the GUI!!!
  - Test if passwords are correct
- 20230908 v5.0
  - Fixed MI-VSX909-10 
    - Added sleep timer between commands in order to catch the slow "show run"
'''

import time, os, shutil, sys, importlib.util
from getpass import getpass
from netmiko import Netmiko
from datetime import datetime
import paramiko
from paramiko import SSHClient
from askCredentialsGUI_PyQT5 import QApplication, QMainWindow, MainWindow
#from askCredentialsGUI_PyQT5_NOISE import QApplication, QMainWindow, MainWindow

def archiveBackup():
  '''Check if the needed folders exists, if they don't it creates them'''
  dirName = now.strftime("%Y%m%d_backup")
  try:
    os.makedirs(f'{path}backupArchive\\{dirName}') # check if it exists first
  except:
    pass
  files = os.listdir(f'{path}todayBackup')
  for i in files:
    shutil.move(f'{path}todayBackup\\{i}',f'{path}backupArchive\\{dirName}')
  return

def uploadToServer(path, serverIP, linuxUser, linuxPSW):
  """Uploads configurations to backup server"""

  logName = now.strftime(f"%Y%m%d_%H%M%S_paramiko_SFTP.log")

  paramiko.util.log_to_file(f"{path}logs\\{logName}")  # The connection logs

  ssh_client = paramiko.SSHClient()
  ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())  # Avoids prompts to add host key
  ssh_client.connect(hostname=serverIP, username=linuxUser, password=linuxPSW)  # Connect to backup server
  print(f"connection established to {serverIP}")

  sftp = ssh_client.open_sftp()

  with os.scandir(f"{path}\\todayBackup") as bck:  # Cycle through all files inside a specific folder
    for data in bck:
      #print(data.name)
      sftp.put(f"{path}\\todayBackup\\{data.name}", f"{data.name}")

  stdin, stdout, stderr = ssh_client.exec_command("ls -l")
  print(stdout.read().decode())

  ssh_client.close()

def writeFile(deco, fileName, path):
  """Open a file and writes the provided input"""

  with open(f'{path}\\todayBackup\\{fileName}', "a") as theFile:
    theFile.write(deco)

def connectionHandler(hosts, user, psw, cmds, diem, deviceNames, path):
  """Connect to nexus devices template

  For every host provided it loops through the provided commands
  """
  for i in hosts:
    h = deviceNames[i]
    theFile=diem.strftime(f"{h}_%Y%m%d_%H%M%S.cfg")
    conn = Netmiko(host=i, username=user, password=psw, device_type="cisco_nxos", timeout=90)
    print(f"Logged into {conn.find_prompt()} ")
    for j in cmds:
      neededOutput = conn.send_command_timing(j)
      if h.startswith("MI-VSX9"): # Check if the current host starts with "MI-VSX9"
        time.sleep(10) # 20230908 Finally fixed the ISE timeout
      writeFile(neededOutput, theFile, path)
    conn.disconnect()

def ASAconnectionHandler(user, psw, cmdAsa, diem, deviceNames, path):
  """Connect to ASA devices template

  It has lots of lists that should be replaced with a templating system
  Loops throught the hosts, than does System context commands
  Loops through contexts and does the needed commands

  Verify incoherency between command variables 
  """

  milieux = ["SYSTEM", "MGMT", "DMZ", "BACKEND", "FRONTEND"]
  connAsa = Netmiko(host="10.312.121.141", username=user, password=psw, device_type="cisco_asa")
  print(f"Logged into {connAsa.find_prompt()} ") # Retrieves the commmand prompt from the device to prove connection
  for cmd in cmdAsa: # Takes first host, loops through cmdASA and saves System configuration
    theFile=diem.strftime("MI-VFX900-1_%Y%m%d_%H%M%S.cfg")
    connAsa.send_command(cmd)
  for c in milieux: # Loops through the contextes and saves each configuration
    theFile=diem.strftime(f"MI-VFX900-1_{c}_%Y%m%d_%H%M%S.cfg")
    neededOutput = connAsa.send_command(f"changeto context {c}")
    neededOutput = connAsa.send_command("write memory") # Can I make a nested for loop in order to make all commands?
    writeFile(neededOutput, theFile, path)
    neededOutput = connAsa.send_command_timing("show running-conf")
    writeFile(neededOutput, theFile, path)
  connAsa.disconnect()

def folderCheckorCreation():
  """Creates needed folders
   logs, todayBackup, backupArchive
  """
  neededFolders="", "logs", "todayBackup", "backupArchive"
  for i in neededFolders:
    if not os.path.isdir(f"{path}{i}"):
      os.makedirs(f"{path}{i}")

def main(diem, path):
  """All the needed information to run the connections

  This is a mess.
  Jinja2 is necessary
  ASA commands can be optimized
  """
  print("Hello! Let's do some magick!")

  folderCheckorCreation()

  app = QApplication([])
  window = MainWindow()
  window.show()
  app.exec_()

  # Retrieve the user and password variables from the GUI
  personal_user = os.environ.get("USERNAME").lower()
  personal_psw = window.personal_psw_entry.text()
  ise_psw = window.ise_psw_entry.text()
  linuxPSW = window.mi5fds_psw_entry.text()

  # Devices names
  deviceNames = {
  "10.312.121.135":"MI-VMX900",
  "10.312.121.136":"MI-VMX901",
  "10.312.121.139":"MI-VMX904",
  "10.312.121.140":"MI-VMX905",
  "10.572.123.7":"MI-VSX909",
  "10.572.123.8":"MI-VSX910",
  "10.312.121.141":"MI-VFX900",
  "10.312.121.142":"MI-VFX901",
  "10.312.121.131":"MI-TSR90",
  "10.572.123.78":"mi5fdsx001"
}
  # Vars Nexus
  nexusHost = ["10.312.121.131", "10.312.121.139", "10.312.121.140"] # Removed ASR MI-VMX900 / MI-VMX901
  asr900 = ["10.312.121.135", "10.312.121.136"]

  # Vars ISE
  userISE = "admin"
  hostISE= "10.572.123.7", "10.572.123.8"
  cmdCiscoIOS = ["terminal length 0", "show running-conf", "exit"]

  # Vars ASA Firepower
  cmdASA = ["terminal pager 0", "write memory"]
  
  # Vars linux backup server
  serverIP = "10.572.123.78"
  linuxUser = "fpusrbck"

  connectionHandler(asr900, personal_user, personal_psw, cmdCiscoIOS, diem, deviceNames, path)
  connectionHandler(nexusHost, personal_user, personal_psw, cmdCiscoIOS, diem, deviceNames, path)
  connectionHandler(hostISE, userISE, ise_psw, cmdCiscoIOS, diem, deviceNames, path) 20250926 Fuck ISE
  ASAconnectionHandler(personal_user, personal_psw, cmdASA, diem, deviceNames, path) 
  uploadToServer(path, serverIP, linuxUser, linuxPSW)
  archiveBackup()

  print("Done!")

if __name__ == "__main__":
  now=datetime.now()
  localUser = os.environ.get("USERNAME")
  path = f"C:\\Users\\{localUser}\\Documents\\backupFastDelivery\\"  # The desired folder where conf get downloaded

try:
  main(now, path)

except KeyboardInterrupt:
    # Handle Ctrl+C interruption
    print("\nProgram interrupted by user.")
    sys.exit(0)  # Exit the program gracefully
