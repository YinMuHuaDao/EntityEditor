const {
    ipcRenderer
} = require('electron');
var fs = require('fs');

var MyCode = require("./MyCode");
var ParamWidget = require("./ParamWidget");

//xml文件解析
var xml2js = require('xml2js');
var parser = new xml2js.Parser();

//字体
var MyFont = require("./MyFont");
var theFont = new MyFont('./app/Res/MAK-MilStd-2525-b.ttf');

var s_smsDataPath = {};
var paramWidget = new ParamWidget();

function smsDataPath(smsFilePath) {

    var fileData, strList;
    var rootPath, str, smsName;

    //自身smsDataPath
    if (smsFilePath.indexOf("/")) {
        strList = smsFilePath.split("/");
    } else if (smsFilePath.indexOf("\\")) {
        strList = smsFilePath.split("\\");
    }
    smsName = strList[strList.length - 1].split(".")[0];
    strList.pop();
    rootPath = strList.join("/");
    s_smsDataPath[smsName] = strList.join("/").concat("/", smsName);
    //include smsDataPath
    fileData = MyCode.readFile(smsFilePath);
    strList = fileData.filter((ele) => {
        return (ele.indexOf("include") >= 0);
    });

    for (var i = 0; i < strList.length; i++) {

        if (strList[i].split("\"")[0].split("(")[1].trim() == "include") {

            var fileNames = MyCode.findSync(rootPath);

            var str = strList[i].split("\"")[1]; //smsFilePath

            for (var i = 0; i < fileNames.length; i++) {
                if (str.indexOf(fileNames[i]) > 0) {
                    str = rootPath.concat("/", fileNames[i]);
                }
            }
            smsDataPath(str);
        }
    }
}

//点击打开按钮是触发
const selectDirBtn = document.getElementById('select-directory');
selectDirBtn.addEventListener('click', function (event) {
    ipcRenderer.send('open-directory-dialog');
    console.log("222");
});

//选择文件时触发
ipcRenderer.on('selectedItem', function (event, filePath) {

    s_smsDataPath = {};

    smsDataPath(filePath);

    var strList, smsName, vrfSimPath;

    var fileNmaeList = s_smsDataPath;

    var treeWidget = document.getElementById("treeWidget");

    treeWidget.innerHTML = null;

    for (let i in fileNmaeList) {

        strList = fileNmaeList[i].split("\/");
        smsName = strList[strList.length - 1].split(".")[0];
        strList.pop();
        vrfSimPath = strList.join("/").concat("/", smsName, "/vrfSim");

        var files = MyCode.findSync(vrfSimPath);

        files.filter((ele) => {
            if (ele.indexOf(".entity") >= 0) {
                return true;
            }
        });

        for (let i = 0; i < files.length; i++) {

            var mydiv = document.createElement("a");
            mydiv.className = "list-group-item";
            var name = files[i].substring(0, files[i].indexOf(".entity"));
            mydiv.innerHTML = name;
            treeWidget.appendChild(mydiv);
            mydiv.setAttribute("smsName", smsName);

            //添加画布元素
            let myCanvas = document.createElement("canvas");
            myCanvas.id = files[i];
            myCanvas.width = 80;
            myCanvas.height = 30;
            myCanvas.style.cssText = "float:left";
            mydiv.appendChild(myCanvas);

            var filesPath = vrfSimPath.concat("/", files[i]);

            fs.readFile(filesPath, "utf-8", function (err, xmlData) {

                parser.parseString(xmlData, function (err, result) {

                    //树形结构图标添加
                    let icon2D = result.simObjects.simObject[0].int[0]["_"];
                    let iconIndex = Number(icon2D);
                    theFont.draw(files[i], iconIndex + 1, "#00f", 0, 20, 18);
                    theFont.draw(files[i], iconIndex + 3, "#f00", 30, 20, 18);
                    theFont.draw(files[i], iconIndex + 2, "#038003", 60, 20, 18);
                });
            });

            //添加监听事件
            mydiv.addEventListener("click", treeItemClick, false);
        }
    }
    paramWidget.init(s_smsDataPath, filePath);
});


function treeItemClick() {

    var smsName = this.getAttribute("smsName");

    var text = this.innerText;

    var entityFilePath = s_smsDataPath[smsName].concat("/vrfSim/", text, ".entity");

    var that = this;

    this.setAttribute("entityFilePath", entityFilePath);

    fs.readFile(entityFilePath, 'utf-8', function (err, xmlData) {

        parser.parseString(xmlData, function (err, result) {

            var platform, platformPath, platformNmae, parameter_type, str, fileData;

            str = result.simObjects.simObject[0].$.platform;

            //路径中有的是斜杠有的是反斜杠
            if (str.indexOf("\/") >= 0) {
                platform = str.split("\/")[1].split(".")[0];
            } else {
                platform = str.split("\\")[1].split(".")[0];
            }

            for (let files in s_smsDataPath) {

                let fileRootPath = s_smsDataPath[files].concat("/vrfSim/platforms");

                let filePath = MyCode.findSync(fileRootPath);

                for (let i = 0; i < filePath.length; i++) {

                    if (filePath[i].indexOf(platform) >= 0) {
                        platformPath = fileRootPath.concat("/", filePath[i]);
                        break;
                    }

                }

            }

            fileData = MyCode.readFile(platformPath);

            var parameterStr = fileData.filter((ele) => {
                if (ele.indexOf("parameter-type") >= 0)
                    return true;
            });

            parameter_type = parameterStr[0].split("\"")[1];

            that.setAttribute("parameter_type", parameter_type);

            str = fileData.filter((ele) => {
                if (ele.indexOf("display-name") >= 0)
                    return true;
            });

            str = str[0].split("\"")[1];

            document.querySelector("#platform").value = str;

            paramWidget.setWidget(that, str);

            var entityEnum = result.simObjects.simObject[0].$.objectType;

            document.querySelector("#entityEnum").value = entityEnum;

            let canBeCreate;
            let canBeCreateArr = result.simObjects.simObject[0].bool;

            canBeCreateArr.forEach(element => {

                if (element.$["paramName"] == "gui-can-create") {
                    if (element._ == "False") {
                        canBeCreate = false;
                    } else {
                        canBeCreate = true;
                    }
                }
            });

            document.querySelector("#canBeCreate").value = canBeCreate;
            document.querySelector("#canBeCreate").checked = canBeCreate;

            //标签
            (function () {
                document.querySelector("#entityLabel").innerHTML = null;
                let guiCategories;
                let guiCategoriesArr = result.simObjects.simObject[0].string;

                guiCategoriesArr.forEach(element => {

                    if (element.$["paramName"] == "gui-categories") {
                        guiCategories = element._;
                    }
                });

                let guiCategoriesSplit = guiCategories.split("\"");
                for (let i = 0; i < guiCategoriesSplit.length; i++) {
                    if (i % 2 != 0) {
                        let mydiv = document.createElement("a");
                        mydiv.className = "btn btn-primary btn-xs";
                        let name = guiCategoriesSplit[i];
                        mydiv.innerHTML = name;
                        document.querySelector("#entityLabel").appendChild(mydiv);
                    }
                }
            })();

            //国家
            (function () {
                document.querySelector("#entityCountry").innerHTML = null;
                let guiDeployableCountries;
                let guiDeployableCountriesArr = result.simObjects.simObject[0].string;

                guiDeployableCountriesArr.forEach(element => {

                    if (element.$["paramName"] == "gui-deployable-countries") {
                        guiDeployableCountries = element._;
                    }
                });

                let guiDeployableCountriesSplit = guiDeployableCountries.split("\"");
                for (let i = 0; i < guiDeployableCountriesSplit.length; i++) {
                    if (i % 2 != 0) {
                        let mydiv = document.createElement("a");
                        mydiv.className = "btn btn-primary btn-xs";
                        let name = guiDeployableCountriesSplit[i];
                        mydiv.innerHTML = name;
                        document.querySelector("#entityCountry").appendChild(mydiv);
                    }
                }
            })();

            //2d图标
            (function () {
                //console.log(result);
                let icon2D = result.simObjects.simObject[0].int[0]["_"];
                let iconIndex = Number(icon2D);
                let dom = document.getElementById("glyph");
                let ctx = dom.getContext("2d");
                let width = dom.offsetWidth;
                let height = dom.offsetHeight;
                ctx.clearRect(0, 0, width, height);

                theFont.draw("glyph", iconIndex + 1, "#00f", 0, 100, 100);
                theFont.draw("glyph", iconIndex + 3, "#f00", 100, 100, 100);
                theFont.draw("glyph", iconIndex + 2, "#038003", 200, 100, 100);
            })();
        });
    });

    document.querySelector("#entityName").value = text;

}