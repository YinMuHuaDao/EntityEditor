var ui = require("./ui");

class CustomControlWidget {
    constructor() {
        this.sensorSignaturesValue = [];
    }

    SensitivityModifier(v, sensorSignatures, hHeadLabel, parent) {
        let myUI = new ui();
        let rootWidget = myUI.SensitivityModifier();
        let map = {},
            strList = [];
        for (let i = 1; i < sensorSignatures.length; i++) {
            map[sensorSignatures[i][0]] = sensorSignatures[i][1];
            strList.push(sensorSignatures[i][1]);
        }
        let hHead = [];
        hHead.push("最大可视距离(km)");
        for (let i = 0; i < hHeadLabel.length; i++) {
            hHead.push(map[hHeadLabel[i]]);
        }

        let dataTitle = rootWidget.querySelector("thead tr");
        let dataBody = rootWidget.querySelector("tbody");

        //数据项
        let tdList = [];
        let tdDataList = [];
        //垂直表头
        for (let i = 2; i < sensorSignatures[0].length; i++) {
            const element = sensorSignatures[0][i];
            let tr = document.createElement("tr");
            dataBody.appendChild(tr);
            let th = document.createElement("th");
            tr.appendChild(th);
            th.innerText = element;
            tdList.push([]);
            tdDataList.push([]);
        }

        //水平表头
        for (let index = 0; index < hHead.length; index++) {
            const element = hHead[index];
            let th = document.createElement("th");
            th.innerText = element;
            dataTitle.appendChild(th);
        }

        let trList = dataBody.querySelectorAll("tr");
        for (let i = 0; i < sensorSignatures[0].length - 2; i++) {
            for (let index = 0; index < hHead.length - 1; index++) {
                let td = document.createElement("td");
                tdList[i][index] = td;
                trList[i].appendChild(td);
            }
        }



        //数据
        for (let i = 1; i < hHead.length; i++) {
            this.sensorSignaturesValue.push([]);
            let row = strList.indexOf(hHead[i]) + 1;
            for (let j = 2; j < sensorSignatures[row].length; j++) {
                // console.log(j - 2);
                // console.log(i - 1);
                // console.log(td);
                //console.log(typeof sensorSignatures[row][j]);
                // if (typeof sensorSignatures[row][j] == "number") {
                //     td.innerText = parseFloat(sensorSignatures[row][j]) * v / 10.0;
                //     this.sensorSignaturesValue[i - 1].push(parseFloat(sensorSignatures[row][j]));
                //     console.log(1);
                // } else {
                //     td.innerText = String(sensorSignatures[row][j]);
                //     console.log(2);
                // }
                tdList[j - 2][i - 1].innerText = (sensorSignatures[row][j]) * v / 10.0;
                this.sensorSignaturesValue[i - 1].push(parseFloat(sensorSignatures[row][j]));
            }
        }


        // $(".js-range-slider").ionRangeSlider({
        //     min: 0,
        //     max: 10,
        //     grid: true,
        //     onStart: function (data) {
        //         data.from = v;
        //     },
        //     onChange: function (data) {
        //         // Called every time handle position is changed
        //         let dataFrom = data.from;
        //         let tr = dataBody.querySelectorAll("tr");
        //         for (let index = 0; index < tr.length; index++) {
        //             const element = tr[index];
        //             let td = tr[index].querySelector(":nth-child(2)");
        //             td.innerText = rowData[index] * dataFrom;
        //         }

        //         // for (let i = 1; i < hHead.length; i++) {
        //         //     let row = strList.indexOf(hHead[i]) + 1;
        //         //     for (let j = 2; j < sensorSignatures[row].length; j++) {
        //         //         let td = tdList[j - 2, i - 1];
        //         //         if (typeof sensorSignatures[row][j] == "number") {
        //         //             td.innerText = parseFloat(sensorSignatures[row][j]) * v / 10.0;
        //         //             this.sensorSignaturesValue[i - 1].push(parseFloat(sensorSignatures[row][j]));
        //         //         } else {
        //         //             td.innerText = String(sensorSignatures[row][j]);
        //         //         }
        //         //     }
        //         // }

        //     }
        // });
        return rootWidget;
    }
}

module.exports = CustomControlWidget;