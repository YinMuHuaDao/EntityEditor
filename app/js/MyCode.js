var fs = require('fs');
//var csv = require('node-csv');
var csv = require('./myCvs');
var join = require('path').join;


class MyCode {
    static readFile(filename) {
        try {
            var data = fs.readFileSync(filename, 'utf8').toString();
            var arr = data.split("\n");
            return arr;
        } catch (err) {
            alert(err);
        }
    }

    //读取csv文件内容
    static readExcle(filepath, cb) {
        // csv.createParser('\t').mapFile(filepath, function (err, data) {
        //     if (err) throw err;
        //     console.log(data);
        //     return data;
        // });

        setTimeout(function () {
            csv.createParser('\t').mapFile(filepath, function (err, data) {
                if (err) throw err;
                cb(data); //回调函数
            });
        }, 10);
    }

    // static readExcleSync(path) {
    //     csv.mapFileSync(path, function (err, data) {
    //         if (err) throw err;
    //         return data;
    //     });

    // }

    // 读取csv文件内容
    static readExcleSync(path) {
        var data = fs.readFileSync(path, 'utf8').toString();
        var table = new Array();
        var rows = new Array();
        rows = data.split("\r\n");
        for (var i = 0; i < rows.length; i++) {
            table.push(rows[i].split(","));
        }
        return table;
    }


    static findSync(startPath) {
        let filename = [];

        function finder(path) {
            let files = fs.readdirSync(path);
            files.forEach((val, index) => {
                let fPath = join(path, val);
                let stats = fs.statSync(fPath);

                if (stats.isFile()) {
                    filename.push(val);
                }
            });
        }
        finder(startPath);
        return filename;
    }
}

module.exports = MyCode;