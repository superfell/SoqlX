# SoqlX

SoqlX is a tool for developers using the Salesforce.com platform, it allows you to easily explore your schema, write and run SOQL queries, make edits to data, and to run Apex code.


![schema viewer](http://www.pocketsoap.com/osx/soqlx/schema.png)


## Build

ZKSforce & Fragaria are pulled in via git submodules, so you need to clone this repo, and fetch the submodules

```
    git clone https://github.com/superfell/SoqlX.git SoqlX
    cd SoqlX
    git submodule init
    git submodule update
```

Now you can open the project in XCode, it requires XCode 10. The Xcode project file is at AppExplorer/AppExplorer.xcodeproj

Building the SoqlXplorer target will build the dependencies, then SoqlX. You may find that the first
build of Fragaria fails with a "Command PhaseScriptExecution failed" error, just hit build again, and
this error goes away.

You should be able to run the built version of SoqlX at this point.
