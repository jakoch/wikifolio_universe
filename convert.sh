#!/bin/bash

export DATE=$(TZ=":Europe/Berlin" date +%d_%m_%Y_%H%M)
export SQLITE_FILE="Investment_Universe_$DATE.sqlite"
export CSV_FILE="Investment_Universe_$DATE.csv"

show_infos() {
  echo -e "\nCPU Info:"
  lscpu | egrep 'Model name|Socket|Thread|NUMA|CPU\(s\)'
  echo -e "\nsqlite3 version:"
  sqlite3 -version
}

install_wiuc() {
  curl -L --output ./wiuc.zip https://github.com/jakoch/wikifolio_universe_converter/releases/download/v0.1.0/Wikifolio_Investment_Universe_Converter-x64-linux-Clang-12.zip
  unzip ./wiuc.zip
  rm ./wiuc.zip
  chmod +x wiuc
}

install_7zip() {
  sudo apt-get install -y p7zip-full
}

install() {
  install_7zip
  install_wiuc
}

convert() {
  echo -e "\nConvert xlsx to sqlite"
  ./wiuc
  mv Investment_Universe.sqlite $SQLITE_FILE
  mv Investment_Universe.csv $CSV_FILE

  # show folder
  ls -lash

  echo -e "\nShow database schema"
  sqlite3 $SQLITE_FILE ".schema"
}

getFilesize() {
  ls -sh "$1" | awk '{print $1}';
}

getSqliteFilename() {
  ls Investment_Universe_*.sqlite
}

compress() {
  SQLITE_FILE=$(getSqliteFilename)

  # compress sqlite, get filesize
  SQLITE_ZIP_FILENAME=$SQLITE_FILE.zip
  7z a -mx9 $SQLITE_ZIP_FILENAME $SQLITE_FILE
  SQLITE_ZIP_FILESIZE=$(getFilesize "$SQLITE_ZIP_FILENAME")

  # show folder
  ls -lash

  EXCEL_FILENAME="Investment_Universe.de.xlsx"
  EXCEL_FILESIZE=$(getFilesize "$EXCEL_FILENAME")

  # write new README
  # ghpages uses jekyll, which has UTF-8 issues. so instead of "Ü" use "&Uuml;"
  echo -n > README.md
  echo -e '# Das gesamte [wikifolio.com Anlageuniversum](https://www.wikifolio.com/de/de/hilfe/tutorials-trader/handel-hinweise/anlageuniversum) im &Uuml;berblick:\n' >> README.md
  echo -e '\n## Excel\n' >> README.md
  echo -e '\n- [Investment_Universe.de.xlsx](https://wikifolio.blob.core.windows.net/prod-documents/Investment_Universe.de.xlsx) ('$EXCEL_FILESIZE')\n' >> README.md
  echo -e '\n## SQLite\n' >> README.md
  echo -e '\n- ['$SQLITE_ZIP_FILENAME']('$SQLITE_ZIP_FILENAME') ('$SQLITE_ZIP_FILESIZE')\n' >> README.md
}

create_tables_for_each_security_type() {
  SQLITE_FILE=$(getSqliteFilename)
  sqlite3 $SQLITE_FILE < query/create-tables-for-securitytypes.sql
}

create_sqlite_for_each_security_type_table() {
  SQLITE_FILE=$(getSqliteFilename)

  echo -e '\n#### By SecurityType\n' >> README.md

  echo -e '\nExporting SecurityType tables into sqlite database files'

  for SECURITYTYPE in $( sqlite3 $SQLITE_FILE "SELECT DISTINCT SecurityType FROM Anlageuniversum" );
  do
    echo -e '\n-----';
    echo SecurityType: $SECURITYTYPE;

    echo -e 'Exporting data selection to CSV file';
    sqlite3 -header -csv $SQLITE_FILE "SELECT * FROM $SECURITYTYPE;" > $SECURITYTYPE-$DATE.csv;

    echo -e 'Creating SQLite for CSV file';
    sqlite3 -csv $SECURITYTYPE-$DATE.sqlite ".import $SECURITYTYPE-$DATE.csv $SECURITYTYPE";

    echo -e 'Moving CSV file into csv folder for diffing';
    mkdir -p csv
    mv $SECURITYTYPE-$DATE.csv csv/

    echo -e 'Create ZIP file';
    declare -A ZIP_FILENAME
    ZIP_FILENAME[$SECURITYTYPE]=$SECURITYTYPE-$DATE.sqlite.zip
    7z a -mx9 ${ZIP_FILENAME[$SECURITYTYPE]} $SECURITYTYPE-$DATE.sqlite;
    declare -A ZIP_FILESIZE
    declare ZIP_FILESIZE[$SECURITYTYPE]=$(getFilesize ${ZIP_FILENAME[$SECURITYTYPE]});

    echo -e 'Append README.md';
    echo -e '\n- ['${ZIP_FILENAME[$SECURITYTYPE]}']('${ZIP_FILENAME[$SECURITYTYPE]}') ('${ZIP_FILESIZE[$SECURITYTYPE]}')\n' >> README.md;
    echo -e '\n-----';
  done;
}

show_files_and_folders() {
  # show folder: ./
  ls -lash
  # show folder: ./csv
  ls -lash ./csv
}

create_security_type_databases() {
  create_tables_for_each_security_type
  create_sqlite_for_each_security_type_table
}
