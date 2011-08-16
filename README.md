# pcapr.Local #

## Introduction

pcapr.Local is a tool for browsing and managing a large repository of packet capture files (pcaps). After you install and configure pcapr.Local with the location of your pcaps, it automatically indexes those pcaps and enables you to navigate your collection using a web browser. Pcapr.Local extends and integrates with [Xtractr](http://code.google.com/p/pcapr/wiki/Xtractr), so it uses the Xtractr web UI hosted on pcapr.net. However, because the UI is configured to talk to the local Xtractr instance managed by pcapr.Local, your data never leaves your network.

In addition to managing pcaps, pcapr.Local helps you leverage your custom Wireshark dissectors to create Scenarios in Mu Studio. Just download the PAR file (Pcap ARchive) file created by pcapr.Local and import it into Mu Studio, where your Wireshark data guides Scenario creation.

You can learn more about pcapr.Local in our announcement [blog](http://labs.mudynamics.com/2011/04/18/announcing-pcaprlocal/).

![pcapr.Local](http://blog.mudynamics.com/wp-content/uploads/2011/04/pcaprlocal.png)

## Dependencies

### Supported Environments

Linux (any flavor). You can install on a dedicated Linux system or in a virtual machine (VM). 

### Ruby & Rubygems

Ruby (1.8.6, 1.8.7, 1.9.2) + Rubygems (1.3.7 or higher). When using Ruby 1.8.6, you must install rubygems 1.3.7. Rubygems officially ceased support for ruby 1.8.6 as of the rubygems 1.4.0 release, so any version 1.4.x or higher will not install on a ruby 1.8.6 system.

### CouchDB
Local and remote installations supported. If you have configured a username and password for the CouchDB service, you'll need to provide those user credentials during the pcapr.Local gem installation. On Ubuntu/Debian you can install CouchDB with:

   $ sudo apt-get install couchdb

### Wireshark (any version)

Pcapr.Local will automatically use the installed version of tshark (a component of Wireshark) to create the pcap indexes. When using a package manager (such as aptitude on Ubuntu), you might need to install tshark command line utility separately if it's not included as part of the Wireshark installation. 

### Zip (any version)
Pcapr.Local requires zip to create PAR files from your indexed pcaps.

## Running pcapr.Local

1. Install the gem. 
2. Run the "startpcapr" executable that is installed with the gem:

    $ startpcapr

This configuration script asks you some basic questions and records your answers in a config file at ~/.pcapr_local/config that will be used on subsequent invocations. After collecting configuration information, the server process returns a prompt but continues running in the background. To monitor the process, tail the pcapr.Local log file with:

    $ tail -F ~/pcapr.Local/log/server.log

3. Add your packet capture files to the pcap directory you configured (default ~/pcapr.Local/pcaps) and wait a few minutes for pcap.Local to index them. 
4. Point your web browser to http://localhost:8080 (or whatever you configured).
5. Stop the pcapr.Local server with:

    $ stoppcapr

## Creating PAR Files

A PAR file (Pcap ARchive) is a format that can be imported into Mu Studio to create a Scenario. Although a PAR file is equivalent to a pcap file for the purposes of Scenario creation, because a PAR contains dissection data from your local Wireshark installation, you'll get the full benefits of any custom dissectors used by that installation. Additionally, when you import a PAR file you'll bypass flow selection and go directly to the Scenario Editor.

### In the Web UI

Point your web browser to http://localhost:8080 (or whatever you configured), then select a pcap to view its details. At the bottom of the details page, click the Download PAR File link.

### On the Command Line

The gem bundles a CLI tool for creating PAR files called 'pcap2par'. To use, just provide a path to your pcap:
 
    $  pcap2par my_traffic.pcap

This creates a PAR file called "export.par" in the current directory. You can optionally specify the name of the output file as a second argument:

    $ pcap2par my_traffic.pcap ~/par_files/my_traffic.par 