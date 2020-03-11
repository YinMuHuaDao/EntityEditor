var MyCode = require("./MyCode");
var ui = require("./ui");
var fs = require('fs');
const xpath = require('xpath');
const dom = require('xmldom').DOMParser;
var CustomControlWidget = require("./CustomControlWidget");


class SystemDialog {
    init(item, sensorSignatures) {
        let sysdefPath = item.getAttribute("sysdefPath");
        let systemName = item.getAttribute("systemName");
        let entityFilePath = item.getAttribute("entityFilePath");

        let content = fs.readFileSync(entityFilePath, {
            encoding: 'UTF-8'
        });
        // 构造dom
        let doc = new dom().parseFromString(content, 'text/xml');
        let myUI = new ui();

        let rootWidget = document.querySelector("#systemContent");
        rootWidget.innerHTML = null;

        let fileData = MyCode.readFile(sysdefPath);
        let strList = fileData.filter((ele) => {
            return (ele.indexOf("system-description") >= 0);
        });
        let str = strList[0].split("\"")[1];
        let title = document.createElement("h6");
        title.innerText = str;
        rootWidget.appendChild(title);

        let paraList = [],
            paraListLen, paraName,
            paraBegin = false,
            paraEnd = true,
            paraKey, paraValue, indexParaBegin, indexParaEnd;

        for (let index = 0; index < fileData.length; index++) {
            const element = fileData[index];
            if (element.indexOf("parameter-data-list") >= 0) {
                indexParaBegin = index;

            }
            if (element.indexOf("meta-data-entry-list") >= 0) {
                indexParaEnd = index;
            }
        }

        for (let row = indexParaBegin + 1; row < indexParaEnd; row++) {
            if (fileData[row].indexOf("-parameter-data") >= 0) { //参数开始
                paraName = fileData[row].split("(")[1].trim();
                paraList.push({});
                paraBegin = true;
                paraEnd = false;
            } else if (fileData[row].trim() == ")") { //参数结束
                paraBegin = false;
                paraEnd = true;
            } else if (paraBegin && !paraEnd) { //解析参数
                let rowData = fileData[row].trim();
                //找出第一个空格位置
                let indexFirSpace = rowData.indexOf(" ");
                paraKey = rowData.slice(0, indexFirSpace).split("(")[1].trim();
                //找出最后一个“)”的位置
                paraValue = rowData.slice(indexFirSpace);
                let indexLastBracket = paraValue.lastIndexOf(")");
                paraValue = paraValue.slice(0, indexLastBracket).trim();
                paraValue = paraValue.replace(/\"/g, "");
                paraListLen = paraList.length;
                paraList[paraListLen - 1][paraKey] = paraValue;

            }
        }
        let variableType, variableValue;
        for (let i = 0; i < paraList.length; i++) {
            let items;
            variableType = paraList[i]["variable-type"];
            if (variableType == "DtRwOffsetVector") {
                variableValue = paraList[i]["default-value"];
                let model = myUI.DtRwOffsetVector();
                items = xpath.select("//componentSystem[@systemName=" + "\'" + systemName + "\'" + "]/bodyPosition[@paramName=" +
                    "\'" + paraList[i]["parameter-name"] + "\'" + "]", doc);
                if (items.length < 0) {
                    alert("查询参数有误！");
                }
                let attr = items[0].attributes;
                let forward = attr.getNamedItem("forward").nodeValue;
                let right = attr.getNamedItem("right").nodeValue;
                let down = attr.getNamedItem("down").nodeValue;
                model.querySelector(".title").innerText = paraList[i]["display-label"];
                model.querySelectorAll("input")[0].value = forward;
                model.querySelectorAll("input")[1].value = right;
                model.querySelectorAll("input")[2].value = down * -1;
                rootWidget.appendChild(model);
            } else if (variableType == "DtRwTaitBryan") {
                variableValue = paraList[i]["default-value"];
                let model = myUI.DtRwTaitBryan();
                items = xpath.select("//componentSystem[@systemName=" + "\'" + systemName + "\'" + "]/orientation[@paramName=" +
                    "\'" + paraList[i]["parameter-name"] + "\'" + "]", doc);
                if (items.length < 0) {
                    alert("查询参数有误！");
                }
                let attr = items[0].attributes;
                let yaw = attr.getNamedItem("yaw").nodeValue;
                let roll = attr.getNamedItem("roll").nodeValue;
                let pitch = attr.getNamedItem("pitch").nodeValue;
                model.querySelector(".title").innerText = paraList[i]["display-label"];
                model.querySelectorAll("input")[0].value = yaw * 57.3;
                model.querySelectorAll("input")[1].value = roll * 57.3;
                model.querySelectorAll("input")[2].value = pitch * 57.3;
                rootWidget.appendChild(model);
            } else if (variableType == "DtRwReal" || variableType == "DtRwInt" || variableType == "DtRwString") {
                if (variableType == "DtRwReal") {
                    items = xpath.select("//componentSystem[@systemName=" + "\'" + systemName + "\'" + "]/real[@paramName=" +
                        "\'" + paraList[i]["parameter-name"] + "\'" + "]", doc);
                    if (items.length < 0) {
                        alert("查询参数有误！");
                    }
                } else if (variableType == "DtRwInt") {
                    items = xpath.select("//componentSystem[@systemName=" + "\'" + systemName + "\'" + "]/int[@paramName=" +
                        "\'" + paraList[i]["parameter-name"] + "\'" + "]", doc);
                    if (items.length < 0) {
                        alert("查询参数有误！");
                    }
                } else if (variableType == "DtRwString") {
                    items = xpath.select("//componentSystem[@systemName=" + "\'" + systemName + "\'" + "]/string[@paramName=" +
                        "\'" + paraList[i]["parameter-name"] + "\'" + "]", doc);
                    if (items.length < 0) {
                        alert("查询参数有误！");
                    }
                }

                if (paraList[i]["parameter-name"] == "sensor-sensitivity-start") {
                    //SensitivityModifier
                    //水平表头
                    let hHeadLabel = [];
                    strList = fileData.filter((ele) => {
                        return (ele.indexOf("sensor-domain") >= 0);
                    });;
                    if (strList.length > 0) {
                        for (let i = 0; i < strList.length; i++) {
                            if (strList[i].split("\"")[0].split("(")[1].trim() == "sensor-domain") {
                                str = strList[i].split("\"")[1];
                                hHeadLabel.push(str.concat("-signature"));
                            }
                        }
                        let mYCustomControlWidget = new CustomControlWidget();
                        let model = mYCustomControlWidget.SensitivityModifier(items[0].firstChild.data * 10, sensorSignatures, hHeadLabel, this);
                        rootWidget.appendChild(model);
                    }
                } else {
                    let model = myUI.DtRwReal();
                    model.querySelectorAll("label")[1].innerHTML = paraList[i]["display-label"].concat(":");
                    model.querySelector("input").value = (items[0].firstChild.data);
                    rootWidget.appendChild(model);
                }
            } else if (variableType == "DtRwBoolean" || variableType == "DtRwBool") {

                let items = xpath.select("//componentSystem[@systemName=" + "\'" + systemName + "\'" + "]/bool[@paramName=" +
                    "\'" + paraList[i]["parameter-name"] + "\'" + "]", doc);

                if (items.length < 0) {
                    alert("查询参数有误！");
                }
                let model = myUI.MyCheckBox();
                model.querySelector("span").innerText = paraList[i]["display-label"];


                if (items[0].firstChild.data.trim() == "False") {
                    model.querySelector("input").checked = false;

                } else {
                    model.querySelector("input").checked = true;

                }
                rootWidget.appendChild(model);
            }
        }
    }
}

module.exports = SystemDialog;