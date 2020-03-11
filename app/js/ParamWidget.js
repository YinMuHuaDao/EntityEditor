//自定义数据类型
var {
    PlatformType
} = require("./MyDefine");
//工具类
var MyCode = require("./MyCode");
var fs = require('fs');
//ui界面
var ui = require('./ui.js');
//xml文档解析
const xpath = require('xpath');
const dom = require('xmldom').DOMParser;
//弹框
var systemDialog = require("./SystemDialog");

class ParamWidget {
    constructor() {
        this.s_platformTypeMap = {}; //平台类型
        this.s_rootPath = ""; ////示例："C:\MAK\vrforces4.6\data\simulationModelSets"
        this.s_smsDataPath = {}; //<smsName,rootPath\smsName>
        this.s_origin = {}; //<offsetType,名称>
        this.s_movementDynamics = {}; //<allowed-state-repository-types,名称列表>
        this.s_damage = {}; //<allowed-state-repository-types，名称列表>
        this.s_sensorSignatures = {};
        this.paramWidgetMap = {};
        this.isInit = false;
    }
    platformInit() {
        if (!this.isInit) {
            var parentNode = document.getElementById("rightPanes");
            var myUi = new ui();

            var Ground_Vehicle = myUi.createHTML("Ground_Vehicle");
            Ground_Vehicle.id = "Ground_Vehicle";
            Ground_Vehicle.style.display = "none";
            parentNode.appendChild(Ground_Vehicle);
            this.paramWidgetMap["Ground Vehicle"] = Ground_Vehicle;

            var Fixed_Wing = myUi.createHTML("Fixed_Wing");
            Fixed_Wing.id = "Fixed_Wing";
            Fixed_Wing.style.display = "none";
            parentNode.appendChild(Fixed_Wing);
            this.paramWidgetMap["Fixed Wing"] = Fixed_Wing;

            var Missile = myUi.createHTML("Missile");
            Missile.id = "Missile";
            Missile.style.display = "none";
            parentNode.appendChild(Missile);
            this.paramWidgetMap["Missile"] = Missile;

            var Rotary_Wing = myUi.createHTML("Rotary_Wing");
            Rotary_Wing.id = "Rotary_Wing";
            Rotary_Wing.style.display = "none";
            parentNode.appendChild(Rotary_Wing);
            this.paramWidgetMap["Rotary Wing"] = Rotary_Wing;

            var Subsurface = myUi.createHTML("Subsurface");
            Subsurface.id = "Subsurface";
            Subsurface.style.display = "none";
            parentNode.appendChild(Subsurface);
            this.paramWidgetMap["Subsurface"] = Subsurface;

            var Surface_Ship = myUi.createHTML("Surface_Ship");
            Surface_Ship.id = "Surface_Ship";
            Surface_Ship.style.display = "none";
            parentNode.appendChild(Surface_Ship);
            this.paramWidgetMap["Surface Ship"] = Surface_Ship;

            this.isInit = true;
        }
    }

    init(smsDataPath, smsFilePath) {

        var strList;
        this.s_smsDataPath = smsDataPath;
        //注册平台
        this.platformInit();
        //根路径
        this.s_rootPath = {};
        if (smsFilePath.indexOf("/")) {
            strList = smsFilePath.split("/");
        } else if (smsFilePath.indexOf("\\")) {
            strList = smsFilePath.split("\\");
        }
        strList.pop();
        this.s_rootPath = strList.join("/");
        this.s_origin = {};
        this.originInit();
        this.s_movementDynamics = {};
        this.movementDynamicsInit(smsFilePath);
        this.s_damage = {};
        this.damageInit(smsFilePath);
        this.s_sensorSignatures = MyCode.readExcleSync(smsFilePath.split(".sms")[0] + "/extra/sensor-signatures.csv");
    }


    paramWidgetInit(item, rootWidget) {
        var entityFilePath;
        var that = this;
        //读取xml（DOM方式）
        entityFilePath = item.getAttribute("entityFilePath");

        let content = fs.readFileSync(entityFilePath, {
            encoding: 'UTF-8'
        });
        // 构造dom
        let doc = new dom().parseFromString(content, 'text/xml');

        let boundingVolume = xpath.select("//boundingVolume", doc);
        if (boundingVolume.length > 0) {
            let id = rootWidget.id;
            let idStr = "#" + id;
            var rootWidget = document.querySelector(idStr);
            if (rootWidget) {
                //体积
                if (rootWidget.querySelector(".dimensions")) {
                    let nodeList = xpath.select("//dimensions", doc);
                    if (nodeList.length == 1) {
                        var attr = nodeList[0].attributes;
                        let length = attr.getNamedItem("length").nodeValue;
                        let width = attr.getNamedItem("width").nodeValue;
                        let height = attr.getNamedItem("height").nodeValue;
                        if (rootWidget.querySelector(".length")) {
                            rootWidget.querySelector(".length").value = length;
                        }
                        if (rootWidget.querySelector(".width")) {
                            rootWidget.querySelector(".width").value = width;
                        }
                        if (rootWidget.querySelector(".height")) {
                            rootWidget.querySelector(".height").value = height;
                        }
                    } else {
                        if (rootWidget.querySelector(".length")) {
                            rootWidget.querySelector(".length").disabled = "disabled";
                        }
                        if (rootWidget.querySelector(".width")) {
                            rootWidget.querySelector(".width").disabled = "disabled";
                        }
                        if (rootWidget.querySelector(".height")) {
                            rootWidget.querySelector(".height").disabled = "disabled";
                        }
                    }
                }
                //原点
                if (rootWidget.querySelector(".offsetType")) {
                    let offsetType = boundingVolume[0].attributes.getNamedItem("offsetType").nodeValue;
                    let arr = ["center", "ground-center", "custom"];
                    let index = arr.indexOf(offsetType);
                    rootWidget.querySelector(".offsetType").selectedIndex = index;
                }
                //偏移
                if (rootWidget.querySelector(".offset")) {
                    let nodeList = xpath.select("//offset", doc);
                    if (nodeList.length == 1) {
                        let attr = nodeList[0].attributes;
                        let forward = attr.getNamedItem("forward").nodeValue;
                        let right = attr.getNamedItem("right").nodeValue;
                        let down = attr.getNamedItem("down").nodeValue;
                        if (rootWidget.querySelector(".offset-front")) {
                            rootWidget.querySelector(".offset-front").value = forward;
                        }
                        if (rootWidget.querySelector(".offset-right")) {
                            rootWidget.querySelector(".offset-right").value = right;
                        }
                        if (rootWidget.querySelector(".offset-up")) {
                            rootWidget.querySelector(".offset-up").value = down;
                        }
                    } else {
                        if (rootWidget.querySelector(".offset-front")) {
                            rootWidget.querySelector(".offset-front").disabled = "disabled";
                        }
                        if (rootWidget.querySelector(".offset-right")) {
                            rootWidget.querySelector(".offset-right").disabled = "disabled";
                        }
                        if (rootWidget.querySelector(".offset-up")) {
                            rootWidget.querySelector(".offset-up").disabled = "disabled";
                        }
                    }
                }

                //其他支撑
                if (xpath.select("//bodyPosition", doc).length > 0) {
                    let nodeList = xpath.select("//bodyPosition", doc);

                    nodeList.forEach((ele) => {
                        //节点属性
                        let attr = ele.attributes;
                        let length = attr.length;
                        let paramName = attr[0].nodeValue;
                        for (let index = 1; index < length; index++) {
                            const elementName = attr[index].nodeName;
                            const elementValue = attr[index].nodeValue;
                            let objectName = paramName.concat("-").concat(elementName);
                            if (rootWidget.querySelector("." + objectName)) {
                                rootWidget.querySelector("." + objectName).value = elementValue;
                            }
                        }
                    });
                }

                //传感信号
                if (xpath.select("//sensorSignatures", doc).length > 0) {
                    let nodeList = xpath.select("//sensorSignatures/real", doc);
                    nodeList.forEach((ele) => {
                        //节点属性
                        let data = ele.firstChild.data;
                        let attr = ele.attributes;
                        let paramName = attr[0].nodeValue;
                        for (let index = 0; index < nodeList.length; index++) {
                            if (rootWidget.querySelector("." + paramName)) {
                                rootWidget.querySelector("." + paramName).value = data;
                            }
                        }
                    });
                }

                //实体类型
                if (xpath.select("//entityType", doc).length > 0) {
                    let nodeList = xpath.select("//entityType", doc);
                    nodeList.forEach((ele) => {
                        //节点属性
                        let data = ele.firstChild.data;
                        let attr = ele.attributes;
                        let paramName = attr[0].nodeValue;
                        if (rootWidget.querySelector("." + paramName)) {
                            let item = rootWidget.querySelector("." + paramName);
                            let option = item.querySelectorAll("option");
                            for (let index = 0; index < option.length; index++) {
                                let element = option[index];
                                let text = element.innerText;
                                if (text == data) {
                                    item.selectedIndex = index;
                                }

                            }
                        }
                    });
                }

                //单选框
                if (xpath.select("//bool", doc).length > 0) {
                    let nodeList = xpath.select("//bool", doc);
                    nodeList.forEach((ele) => {
                        //节点属性
                        let data = ele.firstChild.data;
                        let boolValue;
                        if (data == "False") {
                            boolValue = false;
                        } else {
                            boolValue = true;
                        }
                        let attr = ele.attributes;
                        let paramName = attr[0].nodeValue;
                        if (rootWidget.querySelector("." + paramName)) {
                            rootWidget.querySelector("." + paramName).checked = boolValue;
                        }

                    });
                }

                //string类值
                if (xpath.select("//string", doc).length > 0) {
                    let nodeList = xpath.select("//string", doc);
                    nodeList.forEach((ele) => {
                        //节点属性
                        let attr = ele.attributes;
                        let paramName = attr[0].nodeValue;
                        if (rootWidget.querySelector("." + paramName)) {
                            let data = ele.firstChild.data;
                            rootWidget.querySelector("." + paramName).value = data;

                        }
                    });
                }


                //real
                if (xpath.select("//real", doc).length > 0) {
                    let nodeList = xpath.select("//real", doc);
                    nodeList.forEach((ele) => {
                        //节点属性
                        let attr = ele.attributes;
                        let paramName = attr[0].nodeValue;
                        if (rootWidget.querySelector("." + paramName)) {
                            let data = ele.firstChild.data;
                            rootWidget.querySelector("." + paramName).value = data;
                        }
                    });
                }

                //int
                if (xpath.select("//int", doc).length > 0) {
                    let nodeList = xpath.select("//int", doc);
                    nodeList.forEach((ele) => {
                        //节点属性
                        let attr = ele.attributes;
                        let paramName = attr[0].nodeValue;
                        let reg = /^[1-9]/;
                        if (!paramName.match(reg)) {
                            if (rootWidget.querySelector("." + paramName)) {
                                let data = ele.firstChild.data;
                                rootWidget.querySelector("." + paramName).value = data;
                            }
                        }
                    });
                }
                //movementDynamics,damage
                {
                    let smsName, parameter_type;
                    smsName = item.getAttribute("smsName");
                    parameter_type = item.getAttribute("parameter_type");
                    if (xpath.select("//componentSystem", doc).length > 0) {
                        let nodeList = xpath.select("//componentSystem", doc);
                        nodeList.forEach((ele) => {
                            //节点属性
                            let attr = ele.attributes;
                            let paramName = attr[0].nodeValue;
                            //movementDynamics
                            if (paramName == "movement") {
                                let str = attr[1].nodeValue.split("movement\\")[1];
                                let w = rootWidget.querySelector(".movement-system");
                                if (w)
                                    this.movementDynamics(idStr, ".movement-system", smsName, parameter_type, str);
                            }
                            //movementDynamics
                            if (paramName == "damage") {
                                let str = attr[1].nodeValue.split("damage\\")[1];
                                let w = rootWidget.querySelector(".damage-system");
                                if (w)
                                    this.damage(idStr, ".damage-system", smsName, parameter_type, str);
                            }
                        });
                    }
                }

                //传感器系统、武器系统、其他系统
                {
                    if (xpath.select("//componentSystem", doc).length > 0) {
                        let nodeList = xpath.select("//componentSystem", doc);
                        if (rootWidget.querySelector(".sensor-system")) {
                            rootWidget.querySelector(".sensor-system").innerHTML = null;
                        }
                        if (rootWidget.querySelector(".weapon-system")) {
                            rootWidget.querySelector(".weapon-system").innerHTML = null;
                        }
                        if (rootWidget.querySelector(".other-system")) {
                            rootWidget.querySelector(".other-system").innerHTML = null;
                        }
                        //弹出框标题
                        nodeList.forEach((ele) => {
                            //节点属性
                            let attr = ele.attributes;
                            let paramName = attr[0].nodeValue;
                            let systemWidget;
                            if (paramName.indexOf("sensor") >= 0 || paramName.indexOf("weapon") >= 0 || paramName.indexOf("other") >= 0) {
                                let str = attr[1].nodeValue;
                                let strList = entityFilePath.split("\/");
                                strList.pop();
                                let sysdefPath = strList.join("/");

                                if (paramName.indexOf("sensor") >= 0) {
                                    strList = str.split("sensors\\");
                                    sysdefPath = sysdefPath.concat("\/systems").concat("\/sensors\/").concat(strList[1]);
                                    systemWidget = rootWidget.querySelector(".sensor-system");
                                }
                                if (paramName.indexOf("weapon") >= 0) {
                                    strList = str.split("weapons\\");
                                    sysdefPath = sysdefPath.concat("\/systems").concat("\/weapons\/").concat(strList[1]);
                                    systemWidget = rootWidget.querySelector(".weapon-system");
                                }
                                if (paramName.indexOf("other") >= 0) {
                                    strList = str.split("other\\");
                                    sysdefPath = sysdefPath.concat("\/systems").concat("\/other\/").concat(strList[1]);
                                    systemWidget = rootWidget.querySelector(".other-system");
                                }
                                let fileData = MyCode.readFile(sysdefPath);
                                strList = fileData.filter((ele) => {
                                    return (ele.indexOf("system-name") >= 0);
                                });
                                for (let i = 0; i < strList.length; i++) {
                                    if (strList[i].split("\"")[0].split("(")[1].trim() == "system-name") {
                                        str = strList[i].split("\"")[1];
                                        break;
                                    }
                                }
                                let listItem = document.createElement("a");
                                listItem.innerText = str;
                                listItem.className = "list-group-item";
                                listItem.setAttribute("sysdefPath", sysdefPath);
                                listItem.setAttribute("systemName", paramName);
                                listItem.setAttribute("entityFilePath", entityFilePath);
                                listItem.setAttribute("title", str);
                                systemWidget.appendChild(listItem);

                            }
                        });

                        let systemList = ["sensor-system", "weapon-system", "other-system"];
                        for (let i = 0; i < systemList.length; i++) {
                            let w = rootWidget.querySelector("." + systemList[i]);
                            if (w) {
                                let itemList = w.querySelectorAll("a");
                                itemList.forEach((ele) => {
                                    ele.addEventListener("dblclick", function () {
                                        let container = document.getElementById('div-child');
                                        container.style.display = "block";

                                        let title = this.getAttribute("title");
                                        let titleCon = container.querySelector('span');
                                        titleCon.innerText = title;

                                        let mySysDialog = new systemDialog();
                                        mySysDialog.init(this, that.s_sensorSignatures);

                                    });
                                });
                            }
                        }
                    }

                }
            }
        }
    }

    origin(comboBoxId, query) {

    }

    movementDynamics(rootName, name, smsName, parameter_type, str) {

        let rootWidget = document.querySelector(rootName);
        let comboBox = rootWidget.querySelector(name);
        comboBox.innerHTML = null;
        let list = this.s_movementDynamics[parameter_type];
        let oOption = document.createElement("OPTION");

        oOption.text = "Immobile";
        oOption.value = "Immobile";
        comboBox.add(oOption);

        list.forEach(function (ele) {
            let oOption = document.createElement("OPTION");
            oOption.text = ele;
            oOption.value = ele;
            comboBox.add(oOption);
        });
        //当前选项
        //var str= result.simObjects.simObject[0].componentSystem[1].$["platform"].split("movement")[1],
        var path,
            fileData,
            comboBoxString,
            comboBoxText;

        path = this.s_smsDataPath[smsName].concat("/vrfSim/systems/movement/").concat(str);

        fileData = MyCode.readFile(path);

        comboBoxString = fileData.filter((ele) => {
            return (ele.indexOf("system-name") >= 0);
        });
        comboBoxText = comboBoxString[0].split("\"")[1];

        var index;
        for (let i = 0; i < list.length; i++) {
            if (comboBoxText == list[i]) {
                index = i + 1;
            }
        }
        comboBox.selectedIndex = index;

    }

    setWidget(item, platformType) {

        if (platformType in this.paramWidgetMap) {
            //初始化窗口
            for (const key in this.paramWidgetMap) {
                if (this.paramWidgetMap.hasOwnProperty(key)) {
                    const element = this.paramWidgetMap[key];
                    element.style.display = "none";
                }
            }
            this.paramWidgetInit(item, this.paramWidgetMap[platformType]);
            this.paramWidgetMap[platformType].style.display = "block";
        } else {
            for (const key in this.paramWidgetMap) {
                if (this.paramWidgetMap.hasOwnProperty(key)) {
                    const element = this.paramWidgetMap[key];
                    element.style.display = "none";
                }
            }
            alert("   模板不存在！！！   ");
        }
    }

    damage(rootName, name, smsName, parameter_type, str) {

        let rootWidget = document.querySelector(rootName);
        let comboBox = rootWidget.querySelector(name);
        comboBox.innerHTML = null;
        let list = this.s_damage[parameter_type];
        let oOption = document.createElement("OPTION");
        oOption.text = "Undamagable";
        oOption.value = "Undamagable";
        comboBox.add(oOption);

        list.forEach(function (ele) {
            let oOption = document.createElement("OPTION");
            oOption.text = ele;
            oOption.value = ele;
            comboBox.add(oOption);
        });
        //当前选项
        // var str = result.simObjects.simObject[0].componentSystem[0].$["platform"].split("damage")[1],
        var path,
            fileData,
            comboBoxString,
            comboBoxText;

        path = this.s_smsDataPath[smsName].concat("/vrfSim/systems/damage/").concat(str);
        fileData = MyCode.readFile(path);

        comboBoxString = fileData.filter((ele) => {
            return (ele.indexOf("system-name") >= 0);
        });
        comboBoxText = comboBoxString[0].split("\"")[1];

        var index;
        for (let i = 0; i < list.length; i++) {
            if (comboBoxText == list[i]) {
                index = i + 1;
            }
        }
        comboBox.selectedIndex = index;
    }

    originInit() {

        this.s_origin["center"] = "中心";
        this.s_origin["ground-center"] = "底部中点";
        this.s_origin["custom"] = "自定义";
    }



    // 存储目录下文件名

    movementDynamicsInit(smsFilePath) {

        var fileData, strList, filePath;
        var rootPath, smsName, path;

        var that = this;

        if (smsFilePath.indexOf("/")) {
            strList = smsFilePath.split("/");
        } else if (smsFilePath.indexOf("\\")) {
            strList = smsFilePath.split("\\");
        }

        smsName = strList[strList.length - 1].split(".")[0];
        strList.pop();
        rootPath = strList.join("/");
        path = rootPath;
        path = path.concat("/", smsName, "/vrfsim", "/systems", "/movement");

        var files = MyCode.findSync(path);

        files.forEach(function (ele) {

            filePath = path.concat("/", ele);
            fileData = MyCode.readFile(filePath);
            var parameter_type, system_name;

            strList = fileData.filter((ele) => {
                return (ele.indexOf("allowed-state-repository-types") >= 0);
            });

            for (var i = 0; i < strList.length; i++) {
                if (strList[i].split("\"")[0].split("(")[1].trim() == "allowed-state-repository-types") {
                    parameter_type = strList[i].split("\"")[1];
                    break;
                }
            }

            strList = fileData.filter((ele) => {
                return (ele.indexOf("system-name") >= 0);
            });

            for (var i = 0; i < strList.length; i++) {
                if (strList[i].split("\"")[0].split("(")[1].trim() == "system-name") {
                    system_name = strList[i].split("\"")[1];
                    break;
                }
            }

            if (that.s_movementDynamics[parameter_type] == null) {

                that.s_movementDynamics[parameter_type] = [];
            }

            that.s_movementDynamics[parameter_type].push(system_name);
        });
    }

    damageInit(smsFilePath) {

        var fileData, strList, filePath;
        var rootPath, smsName, path;

        var that = this;

        if (smsFilePath.indexOf("/")) {
            strList = smsFilePath.split("/");
        } else if (smsFilePath.indexOf("\\")) {
            strList = smsFilePath.split("\\");
        }

        smsName = strList[strList.length - 1].split(".")[0];
        strList.pop();
        rootPath = strList.join("/");
        path = rootPath;
        path = path.concat("/", smsName, "/vrfsim", "/systems", "/damage");

        var files = MyCode.findSync(path);

        files.forEach((ele) => {
            filePath = path.concat("/", ele);
            fileData = MyCode.readFile(filePath);
            strList = fileData.filter((ele) => {
                return (ele.indexOf("system-categories") >= 0);
            });
            if (strList[0].split("\"")[1] == "damage") {
                var parameter_type, system_name;

                let myList = fileData.filter((ele) => {
                    return (ele.indexOf("allowed-state-repository-types") >= 0);
                });

                for (var i = 0; i < myList.length; i++) {
                    if (myList[i].split("\"")[0].split("(")[1].trim() == "allowed-state-repository-types") {
                        parameter_type = myList[i].split("\"")[1];
                        break;
                    }
                }

                strList = fileData.filter((ele) => {
                    return (ele.indexOf("system-name") >= 0);
                });

                for (var i = 0; i < strList.length; i++) {
                    if (strList[i].split("\"")[0].split("(")[1].trim() == "system-name") {
                        system_name = strList[i].split("\"")[1];
                        break;
                    }
                }

                if (that.s_damage[parameter_type] == null) {

                    that.s_damage[parameter_type] = [];
                }

                that.s_damage[parameter_type].push(system_name);

            }
        });
    }
}
module.exports = ParamWidget;