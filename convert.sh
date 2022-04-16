#!/bin/bash

# Constants

export DATE=$(TZ=":Europe/Berlin" date +%d_%m_%Y_%H%M)
export SQLITE_FILE="Investment_Universe-$DATE.sqlite"
export CSV_FILE="Investment_Universe-$DATE.csv"

# Helper functions

getFilesize() {
  ls -sh "$1" | awk '{print $1}';
}

getSqliteFilename() {
  ls Investment_Universe-*.sqlite
}

# ---------------------------------------------------------

show_infos() {
  echo -e "\nCPU Info:"
  lscpu | egrep 'Model name|Socket|Thread|NUMA|CPU\(s\)'
  echo -e "\nsqlite3 version:"
  sqlite3 -version
}

install_wiuc() {
  echo -e "\nInstalling Wikifolio Universe Converter"
  version="$(curl -s https://api.github.com/repos/jakoch/wikifolio_universe_converter/releases/latest | jq -r '.tag_name' | cut -c 2-)"; echo "Latest WIUC Version: $version"
  url="https://github.com/jakoch/wikifolio_universe_converter/releases/download/v$version/Wikifolio_Investment_Universe_Converter-v$version-x64-linux-Clang-12.zip"; echo "Download URL: $url"
  curl -L --output ./wiuc.zip $url
  mkdir -p data
  unzip ./wiuc.zip -d data
  rm ./wiuc.zip
  chmod +x data/wiuc
}

install_7zip() {
  echo -e "\nInstalling 7zip"
  sudo apt-get install -y p7zip-full
}

install() {
  install_7zip
  install_wiuc
}

convert() {
  cd data

  echo -e "\nConvert xlsx to sqlite"
  ./wiuc

  echo -e "\nAdding date and time to filenames"
  mv Investment_Universe.sqlite $SQLITE_FILE
  mv Investment_Universe.csv $CSV_FILE

  # show folder
  ls -lash

  echo -e "\nShowing SQLITE SCHEMA"
  sqlite3 $SQLITE_FILE ".schema"

  cd ..
}

compress() {
  cd data

  SQLITE_FILE=$(getSqliteFilename)

  # compress sqlite, get filesize
  SQLITE_ZIP_FILENAME=$SQLITE_FILE.zip
  7z a -mx9 $SQLITE_ZIP_FILENAME $SQLITE_FILE
  SQLITE_ZIP_FILESIZE=$(getFilesize "$SQLITE_ZIP_FILENAME")

  # show folder
  ls -lash

  # get filesize of xlsx
  EXCEL_FILENAME="Investment_Universe.de.xlsx"
  EXCEL_FILESIZE=$(getFilesize "$EXCEL_FILENAME")
  rm Investment_Universe.de.xlsx

  # write new README
  # ghpages uses jekyll, which has UTF-8 issues. so instead of "Ü" use "&Uuml;"
  echo -n > README.md
  echo -e '# Das gesamte [wikifolio.com Anlageuniversum](https://www.wikifolio.com/de/de/hilfe/tutorials-trader/handel-hinweise/anlageuniversum) im &Uuml;berblick:\n' >> README.md
  echo -e '\n### Downloads vom '$DATE'\n' >> README.md
  echo -e '| | XLSX | SQLite | CSV |' >> README.md
  echo -e '|--|--|--|--|' >> README.md
  echo -e '| **Investment Universe** | [xlsx](https://wikifolio.blob.core.windows.net/prod-documents/Investment_Universe.de.xlsx) ('$EXCEL_FILESIZE') | [sqlite]('sqlite/$SQLITE_ZIP_FILENAME') ('$SQLITE_ZIP_FILESIZE') | |' >> README.md

  cd ..
}

create_security_type_databases() {
  cd data

  SQLITE_FILE=$(getSqliteFilename)

  echo -e '\nCreate tables for each SecurityType in main sqlite file'
  sqlite3 $SQLITE_FILE < ../query/create-tables-for-securitytypes.sql

  echo -e '\nExporting SecurityType tables into sqlite database files'

  echo -e '| *By Security Type* ||||' >> README.md

  for SECURITYTYPE in $( sqlite3 $SQLITE_FILE "SELECT DISTINCT SecurityType FROM Anlageuniversum" );
  do
    echo -e '\n----- SecurityType: '$SECURITYTYPE'';

    FILENAME=$SECURITYTYPE-$DATE

    echo -e 'Exporting data selection to CSV file';
    sqlite3 -header -csv $SQLITE_FILE "SELECT * FROM $SECURITYTYPE;" > $FILENAME.csv;

    echo -e 'Zipping CSV file';
    declare -A CSV_FILENAME
    CSV_FILENAME[$SECURITYTYPE]=$FILENAME.csv.zip
    7z a -mx9 ${CSV_FILENAME[$SECURITYTYPE]} $FILENAME.csv;
    declare -A CSV_FILESIZE
    declare CSV_FILESIZE[$SECURITYTYPE]=$(getFilesize ${CSV_FILENAME[$SECURITYTYPE]});

    echo -e 'Creating SQLite for CSV file';
    sqlite3 -csv $FILENAME.sqlite ".import $FILENAME.csv $SECURITYTYPE";

    echo -e 'Zipping SQLite file';
    declare -A ZIP_FILENAME
    ZIP_FILENAME[$SECURITYTYPE]=$FILENAME.sqlite.zip
    7z a -mx9 ${ZIP_FILENAME[$SECURITYTYPE]} $FILENAME.sqlite;
    declare -A ZIP_FILESIZE
    declare ZIP_FILESIZE[$SECURITYTYPE]=$(getFilesize ${ZIP_FILENAME[$SECURITYTYPE]});

    echo -e 'Append README.md';
    echo -e '| **'$SECURITYTYPE'** |  | [sqlite]('sqlite/${ZIP_FILENAME[$SECURITYTYPE]}') ('${ZIP_FILESIZE[$SECURITYTYPE]}') | [csv]('csv/${CSV_FILENAME[$SECURITYTYPE]}') ('${CSV_FILESIZE[$SECURITYTYPE]}') |' >> README.md;
  done;

  cd ..
}

move_files() {
    cd data

    echo -e 'Moving *.csv.zip file into csv folder';
    mkdir -p csv
    mv *.csv.zip csv/

    echo -e 'Moving *.sql.zip files into sqlite folder';
    mkdir -p sqlite
    mv *.sqlite.zip sqlite/

    echo -e 'Deleting csv and sqlite files';
    rm *.csv
    rm *.sqlite

    cd ..
}

show_files_and_folders() {
  ls -lash data
  ls -lash data/csv
  ls -lash data/sqlite
}

run() {
  show_infos
  install
  convert
  compress
  create_security_type_databases
  move_files
  show_files_and_folders
}
