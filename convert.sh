#!/bin/sh

show_cpu_info() {
  lscpu | egrep 'Model name|Socket|Thread|NUMA|CPU\(s\)'
}

install_7zip() {
  sudo apt-get install p7zip-full
}

install_sqlitebiter() {
  wget https://github.com/thombashi/sqlitebiter/releases/download/v0.35.2/sqlitebiter_0.35.2_amd64.deb -O sqlitebiter.deb
  sudo dpkg -i sqlitebiter.deb
  rm sqlitebiter.deb
}

install() {
  install_7zip
  install_sqlitebiter
}

download() {
  wget https://wikifolio.blob.core.windows.net/prod-documents/Investment_Universe.de.xlsx -O Investment_Universe.de.xlsx
}

convert() {
  DATE=$(TZ=":Europe/Berlin" date +%d_%m_%Y_%H%M)        
  SQLITE_FILE="Investment_Universe_$DATE.sqlite"
  
  sqlitebiter -v --max-workers 2 -o $SQLITE_FILE file Investment_Universe.de.xlsx
}

getFilesize { 
  ls -sh "$1" | awk '{print $1}'; 
}

get_xlsx_filename_and_size() {        
  EXCEL_FILENAME="Investment_Universe.de.xlsx"        
  EXCEL_FILESIZE=$(getFilesize "$EXCEL_FILENAME")
}

show_cpu_info
install
download
convert
get_xlsx_filename_and_size
