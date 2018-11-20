#!/bin/bash

discovery(){
  hostalive $1
  screenshot $1
  cleanup $1
  cat ./$1/$foldername/responsive-$(date +"%Y-%m-%d").txt | sort -u | while read line; do
    sleep 1
    dirsearcher $line
    report $1 $line
    echo "$line report generated"
    sleep 1
  done

}

cleanup(){
  cd ./$1/$foldername/screenshots/
  rename 's/_/-/g' -- *
  cd $path
}

hostalive(){
  cat ./$1/$foldername/$1.txt > ./$1/$foldername/alldomains.txt
  cat ./$1/$foldername/mass.txt >> ./$1/$foldername/temp.txt
  cat ./$1/$foldername/crtsh.txt >> ./$1/$foldername/temp.txt
  cat ./$1/$foldername/temp.txt | awk  '{print $1}' | while read line; do
 x="$line"
  echo "${x%?}" >> ./$1/$foldername/alldomains.txt  
done
 	cat ./$1/$foldername/alldomains.txt | sort -u | while read line; do
    if [ $(curl --write-out %{http_code} --silent --output /dev/null -m 5 $line) = 000 ]
    then
      echo "$line was unreachable"
      touch ./$1/$foldername/unreachable.html
      echo "<b>$line</b> was unreachable<br>" >> ./$1/$foldername/unreachable.html
    else
      echo "$line is up"
      echo $line >> ./$1/$foldername/responsive-$(date +"%Y-%m-%d").txt
    fi
  done
}

screenshot(){
    echo "taking a screenshot of $line"
    python ~/tools/webscreenshot/webscreenshot.py -o ./$1/$foldername/screenshots/ -i ./$1/$foldername/responsive-$(date +"%Y-%m-%d").txt --timeout=10 -m
}

recon(){
echo "Recon started.."
echo "Listing subdomains using sublister..."
  python ~/tools/Sublist3r/sublist3r.py -d $1 -t 10 -v -o ./$1/$foldername/$1.txt > /dev/null
echo "Checking cerspotter..."
  curl -s https://certspotter.com/api/v0/certs\?domain\=$1 | jq '.[].dns_names[]' | sed 's/\"//g' | sed 's/\*\.//g' | sort -u | grep $1 >> ./$1/$foldername/$1.txt
  nsrecords $1
echo "Starting discovery..."
  discovery $1
  cat ./$1/$foldername/$1.txt | sort -u > ./$1/$foldername/$1.txt

}

dirsearcher(){
  python3 ~/tools/dirsearch/dirsearch.py -e php,asp,aspx,jsp,html,zip,jar -u $line
}
crtsh(){
 ~/massdns/scripts/ct.py $1 | ~/massdns/bin/massdns -r ~/massdns/lists/resolvers.txt -t A -q -o S -w  ./$1/$foldername/crtsh.txt
}
mass(){
 ~/massdns/scripts/subbrute.py ./all.txt $1 | ~/massdns/bin/massdns -r ~/massdns/lists/resolvers.txt -t A -q -o S | grep -v 142.54.173.92 > ./$1/$foldername/mass.txt 
}
nsrecords(){    
		echo "Started dns records check ..."
		echo "Checking http://crt.sh"
		crtsh $1 > /dev/null
		echo "Starting Massdns Subdomain discovery this may take a while"
		mass $1 > /dev/null
		echo "Massdns finished..."
                cat ./$1/$foldername/mass.txt | grep CNAME >> ./$1/$foldername/cnames.txt
                cat ./$1/$foldername/crtsh.txt | grep CNAME >> ./$1/$foldername/cnames.txt
                cat ./$1/$foldername/cnames.txt | sort -u | while read line; do
                hostrec=$(echo "$line" | awk '{print $1}')
                if [[ $(host $hostrec | grep NXDOMAIN) != "" ]]
                then
                echo "Check the following domain for NS takeover:  $line"
                echo "$line" >> ./$1/$foldername/pos.txt
                else
                echo -ne "working on it...\r"
                fi
                done
		sleep 1 
				}

report(){
  touch ./$1/$foldername/reports/$line.html
  echo "<title> report for $line </title>" >> ./$1/$foldername/reports/$line.html
  echo "<html>" >> ./$1/$foldername/reports/$line.html
  echo "<head>" >> ./$1/$foldername/reports/$line.html
  echo "<link rel=\"stylesheet\" href=\"https://fonts.googleapis.com/css?family=Mina\" rel=\"stylesheet\">" >> ./$1/$foldername/reports/$line.html
  echo "</head>" >> ./$1/$foldername/reports/$line.html
  echo "<body><meta charset=\"utf-8\"> <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"> <link rel=\"stylesheet\" href=\"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css\"> <script src=\"https://ajax.googleapis.com/ajax/libs/jquery/3.3.1/jquery.min.js\"></script> <script src=\"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js\"></script></body>" >> ./$1/$foldername/reports/$line.html
  echo "<div class=\"jumbotron text-center\"><h1> Recon Report for <a/href=\"http://$line.com\">$line</a></h1>" >> ./$1/$foldername/reports/$line.html
  echo "<p> Generated by <a/href=\"https://github.com/nahamsec/lazyrecon\"> LazyRecon</a> on $(date) </p></div>" >> ./$1/$foldername/reports/$line.html


  echo "   <div clsas=\"row\">" >> ./$1/$foldername/reports/$line.html
  echo "     <div class=\"col-sm-6\">" >> ./$1/$foldername/reports/$line.html
  echo "     <div style=\"font-family: 'Mina', serif;\"><h2>Dirsearch</h2></div>" >> ./$1/$foldername/reports/$line.html
  echo "<pre style='display: block;'>" >> ./$1/$foldername/reports/$line.html
  cat ~/tools/dirsearch/reports/$line/* | while read nline; do
  status_code=$(echo "$nline" | awk '{print $1}')
  url=$(echo "$nline" | awk '{print $3}')
  if [[ "$status_code" == *20[012345678]* ]]; then
    echo "<span style='background-color:#00f93645;'><a href='$url'>$nline</a></span>" >> ./$1/$foldername/reports/$line.html
  elif [[ "$status_code" == *30[012345678]* ]]; then
        echo "<span style='background-color:#f9f10045;'><a href='$url'>$nline</a></span>" >> ./$1/$foldername/reports/$line.html
  elif [[ "$status_code" == *40[012345678]* ]]; then
        echo "<span style='background-color:#0000cc52;'><a href='$url'>$nline</a></span>" >> ./$1/$foldername/reports/$line.html
  elif [[ "$status_code" == *50[012345678]* ]]; then
        echo "<span style='background-color:#f9000045;'><a href='$url'>$nline</a></span>" >> ./$1/$foldername/reports/$line.html
  else
    echo "<span>$line</span>" >> ./$1/$foldername/reports/$line.html
  fi
  done
  echo "</pre>   </div>" >> ./$1/$foldername/reports/$line.html

  echo "     <div class=\"col-sm-6\">" >> ./$1/$foldername/reports/$line.html
  echo "<div style=\"font-family: 'Mina', serif;\"><h2>Screeshot</h2></div>" >> ./$1/$foldername/reports/$line.html
  echo "<pre style='display: block;'>" >> ./$1/$foldername/reports/$line.html
  echo "Port 80                              Port 443" >> ./$1/$foldername/reports/$line.html
  echo "<img/src=\"../screenshots/http-$line-80.png\" style=\"max-width: 500px;\"> <img/src=\"../screenshots/https-$line-443.png\" style=\"max-width: 500px;\"> <br>" >> ./$1/$foldername/reports/$line.html
  echo "</pre>" >> ./$1/$foldername/reports/$line.html

  echo "<div style=\"font-family: 'Mina', serif;\"><h2>Dig Info</h2></div>" >> ./$1/$foldername/reports/$line.html
  echo "<pre style='display: block;'>" >> ./$1/$foldername/reports/$line.html
  dig $line >> ./$1/$foldername/reports/$line.html
  echo "</pre>" >> ./$1/$foldername/reports/$line.html

  echo "<div style=\"font-family: 'Mina', serif;\"><h2>Host Info</h1></div>" >> ./$1/$foldername/reports/$line.html
  echo "<pre style='display: block;'>" >> ./$1/$foldername/reports/$line.html
  host $line >> ./$1/$foldername/reports/$line.html
  echo "</pre>" >> ./$1/$foldername/reports/$line.html

  echo "<div style=\"font-family: 'Mina', serif;\"><h2>Response Header</h1></div>" >> ./$1/$foldername/reports/$line.html
  echo "<pre>" >> ./$1/$foldername/reports/$line.html
  curl -sSL -D - $line  -o /dev/null >> ./$1/$foldername/reports/$line.html
  echo "</pre>" >> ./$1/$foldername/reports/$line.html

  echo "<div style=\"font-family: 'Mina', serif;\"><h1>Nmap Results</h1></div>" >> ./$1/$foldername/reports/$line.html
  echo "<pre style='display: block;'>" >> ./$1/$foldername/reports/$line.html
  echo "nmap -sV -T3 -Pn -p3868,3366,8443,8080,9443,9091,3000,8000,5900,8081,6000,10000,8181,3306,5000,4000,8888,5432,15672,9999,161,4044,7077,4040,9000,8089,443,7447,7080,8880,8983,5673,7443,19000,19080" >> ./$1/$foldername/reports/$line.html
  nmap -sV -T3 -Pn -p3868,3366,8443,8080,9443,9091,3000,8000,5900,8081,6000,10000,8181,3306,5000,4000,8888,5432,15672,9999,161,4044,7077,4040,9000,8089,443,7447,7080,8880,8983,5673,7443,19000,19080 $line >> ./$1/$foldername/reports/$line.html
  echo "</pre>">> ./$1/$foldername/reports/$line.html
  

  echo "</html>" >> ./$1/$foldername/reports/$line.html

}
master_report()
{
  echo "<title> Master report for $1 </title>" >> ./$1/$foldername/master_report.html
  echo "<html>" >> ./$1/$foldername/master_report.html
  echo "<head>" >> ./$1/$foldername/master_report.html
  echo "<link rel=\"stylesheet\" href=\"https://fonts.googleapis.com/css?family=Mina\" rel=\"stylesheet\">" >> ./$1/$foldername/master_report.html
  echo "</head>" >> ./$1/$foldername/master_report.html
  echo "<body><meta charset=\"utf-8\"> <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"> <link rel=\"stylesheet\" href=\"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css\"> <script src=\"https://ajax.googleapis.com/ajax/libs/jquery/3.3.1/jquery.min.js\"></script> <script src=\"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js\"></script></body>" >> ./$1/$foldername/master_report.html
  echo "<div class=\"jumbotron text-center\"><h1> Recon Report for <a/href=\"http://$1\">$1</a></h1>" >> ./$1/$foldername/master_report.html
  echo "<p> Generated by <a/href=\"https://github.com/nahamsec/lazyrecon\"> LazyRecon</a> on $(date) </p></div>" >> ./$1/$foldername/master_report.html


  echo "     <div class=\"col-sm-6\">" >> ./$1/$foldername/master_report.html
  echo "     <div style=\"font-family: 'Mina', serif;\"><h2>Total scanned subdomains</h2></div>" >> ./$1/$foldername/master_report.html
  
  echo "<pre style='display: block;'>" >> ./$1/$foldername/master_report.html
  
  echo "SubDomains                   Scanned Urls" >> ./$1/$foldername/master_report.html
  cat ./$1/$foldername/responsive-$(date +"%Y-%m-%d").txt | while read nline; do

  echo "<span><a href='./reports/$nline.html'>$nline</a></span><span>            $(wc -l ~/tools/dirsearch/reports/$nline/* | awk '{print $1}')</span>" >> ./$1/$foldername/master_report.html

  done
  echo "</pre></div>" >> ./$1/$foldername/master_report.html

  echo "     <div class=\"col-sm-6\">" >> ./$1/$foldername/master_report.html
  echo "<div style=\"font-family: 'Mina', serif;\"><h2>Dig Info</h2></div>" >> ./$1/$foldername/master_report.html
  echo "<pre style='display: block;'>" >> ./$1/$foldername/master_report.html
  dig $line >> ./$1/$foldername/master_report.html
  echo "</pre>" >> ./$1/$foldername/master_report.html

  echo "<div style=\"font-family: 'Mina', serif;\"><h2>Host Info</h1></div>" >> ./$1/$foldername/master_report.html
  echo "<pre style='display: block;'>" >> ./$1/$foldername/master_report.html
  host $1 >> ./$1/$foldername/master_report.html
  echo "</pre>" >> ./$1/$foldername/master_report.html

  echo "<div style=\"font-family: 'Mina', serif;\"><h2>Response Header</h1></div>" >> ./$1/$foldername/master_report.html
  echo "<pre>" >> ./$1/$foldername/master_report.html
  curl -sSL -D - $1  -o /dev/null >> ./$1/$foldername/master_report.html
  echo "</pre>" >> ./$1/$foldername/master_report.html

  echo "<div style=\"font-family: 'Mina', serif;\"><h1>Nmap Results</h1></div>" >> ./$1/$foldername/master_report.html
  echo "<pre style='display: block;'>" >> ./$1/$foldername/master_report.html
  echo "nmap -sV -T3 -Pn -p3868,3366,8443,8080,9443,9091,3000,8000,5900,8081,6000,10000,8181,3306,5000,4000,8888,5432,15672,9999,161,4044,7077,4040,9000,8089,443,7447,7080,8880,8983,5673,7443,19000,19080" >> ./$1/$foldername/master_report.html
  nmap -sV -T3 -Pn -p3868,3366,8443,8080,9443,9091,3000,8000,5900,8081,6000,10000,8181,3306,5000,4000,8888,5432,15672,9999,161,4044,7077,4040,9000,8089,443,7447,7080,8880,8983,5673,7443,19000,19080 $1 >> ./$1/$foldername/master_report.html
  echo "</pre>">> ./$1/$foldername/master_report.html
  
  echo "<div style=\"font-family: 'Mina', serif;\"><h2>Dead NSRECORDS</h2></div>" >> ./$1/$foldername/master_report.html
  echo "<pre style='display: block;'>" >> ./$1/$foldername/master_report.html
  cat ./$1/$foldername/pos.txt | while read ns; do 
  echo "<span>$ns</span>" >> ./$1/$foldername/master_report.html
  done
  echo "</pre></div>" >> ./$1/$foldername/master_report.html


  echo "</html>" >> ./$1/$foldername/master_report.html
}

logo(){
  #can't have a bash script without a cool logo :D
  echo "
  _     ____  ____ ___  _ ____  _____ ____ ____  _
 / \   /  _ \/_   \\  \///  __\/  __//   _Y  _ \/ \  /|
 | |   | / \| /   / \  / |  \/||  \  |  / | / \|| |\ ||
 | |_/\| |-||/   /_ / /  |    /|  /_ |  \_| \_/|| | \||
 \____/\_/ \|\____//_/   \_/\_\\____\\____|____/\_/  \|
                                                      "
}

main(){
  clear
  logo

  if [ -d "./$1" ]
  then
    echo "This is a known target."
  else
    mkdir ./$1
  fi
  mkdir ./$1/$foldername
  mkdir ./$1/$foldername/reports/
  mkdir ./$1/$foldername/screenshots/
  touch ./$1/$foldername/crtsh.txt
  touch ./$1/$foldername/mass.txt
  touch ./$1/$foldername/cnames.txt
  touch ./$1/$foldername/pos.txt
 touch ./$1/$foldername/alldomains.txt
  touch ./$1/$foldername/temp.txt 
 touch ./$1/$foldername/unreachable.html
  touch ./$1/$foldername/responsive-$(date +"%Y-%m-%d").txt
  touch ./$1/$foldername/master_report.html
  recon $1
  master_report $1
rm ./$1/$foldername/temp.txt
rm -rf ~/tools/dirsearch/reports/*


    
}
logo
if [[ -z $@ ]]; then
  echo "Error: no targets specified."
  echo "Usage: ./lazyrecon.sh <target>"
  exit 1
fi

path=$(pwd)
foldername=recon-$(date +"%Y-%m-%d")
main $1
