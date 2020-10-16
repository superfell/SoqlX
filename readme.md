# SoqlX

SoqlX is a tool for developers using the Salesforce.com platform, it allows you to easily explore your schema,
write and run SOQL queries, make edits to data, and to run Apex code.


![schema viewer](https://www.pocketsoap.com/osx/soqlx/help/schema.png)


## Build

ZKSforce and Sparkle are managed via [Cocoa Pods](https://cocoapods.org), you'll need to run `pod install` once you've cloned
this repo. Fragaria is pulled in via git submodules, so you need to clone this repo, and fetch the submodules.

```
    git clone --recurse-submodules https://github.com/superfell/SoqlX
    pod install
    
    # or the long way.
    git clone https://github.com/superfell/SoqlX.git SoqlX
    cd SoqlX
    git submodule init
    git submodule update
    pod install
```

Now you can open the project in XCode, remember to open the workspace created by Cocoa Pods.
It requires XCode 10.

Building the SoqlXplorer target will build the dependencies, then SoqlX. You may find that the first
build of Fragaria fails with a "Command PhaseScriptExecution failed" error, just hit build again, and
this error goes away.

You should be able to run the built version of SoqlX at this point.

