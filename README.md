# pcapr.Local #

## Introduction

pcapr.Local is a tool for browsing and managing a large repository of packet captures (pcaps). After you tell pcapr.Local where your pcaps are located, it will index them automatically and let you navigate your collection in the comfort of your web browser. pcapr.Local builds on and integrates with [Xtractr](http://code.google.com/p/pcapr/wiki/Xtractr) so you can analyze your pcaps in the Xtractr web UI. The Xtractr web UI is hosted on pcapr.net but talks to a local Xtractr instance (managed by pcapr.Local) and your data never leaves your network.

In addition to managing your pcaps, you can use pcapr.Local to leverage your custom wireshark dissectors when creating Scenarios in Mu Studio. PAR files (described below) created by pcapr.Local can be imported into Mu Studio just like a pcap, but Mu Studio will use your wireshark data to guide Scenario creation.

## Dependencies

### CouchDB
CouchDB needs to be available. Either or local or remote installation will work. On Ubuntu/Debian you can install CouchDB with:

   $ sudo apt-get install couchdb

### Wireshark

You need to have wireshark installed. In particular the command line "tshark" utility should be available. 

### Ruby

Tested with Ruby 1.8.6, 1.8.7, and 1.9.2.

## Supported environments

Linux only. Sorry.

## Running pcapr.Local

1. Install the gem. 
2. Run the "startpcapr" executable that is installed with the gem:

    $ startpcapr

This will ask you some basic questions, and will record your answers in a config file at ~/.pcapr_local/config that will be used on subsequent invocations. After collecting configuration information, the server process will continue running in the background and you'll get your prompt back. If you like to keep an eye on what's going on you can tail the pcapr.Local log file with:

    $ tail -F ~/pcapr.Local/log/server.log

3. Add pcaps to the pcap directory you configured (default ~/pcapr.Local/pcaps) and wait a short while for them to be noticed and indexed (about a minute). 
4. Point your browser to http://localhost:8080 (or whatever you configured).
5. If you want to stop the pcapr.Local server you can do so with:

    $ stoppcapr

## Creating PAR files

A PAR file (Pcap ARchive) is a format that can be imported onto a Mu Studio to create a Scenario. For purposes of Scenario creation, a PAR file is equivalent to the starting pcap with a couple of exceptions:

1.  The PAR file contains wireshark dissection data from your local wireshark installation. This means you get the full benefits of any custom dissectors you may have.
2.  When you import a PAR you'll bypass the normal flow selection page and go directly to the Scenario editor.

### In the GUI

Select a pcap in the pcapr.Local browser. The page that opens has a link at the bottom that lets you download a PAR file for that pcap.

### On the Command Line

The gem bundles a CLI tool for creating PAR files called 'pcap2par'. Usage is very simple, just provide a path to your pcap:
 
    $  pcap2par my_traffic.pcap

This will create the PAR file called "export.par" in the current directory. You can optionally specify the output file as a second argument:

    $ pcap2par my_traffic.pcap ~/par_files/my_traffic.par 
