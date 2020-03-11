var opentype = require("opentype.js");

//var font = opentype.loadSync('./app/Res/MAK-MilStd-2525-b.ttf');

class MyFont {

    constructor(url) {
        this.font = opentype.loadSync(url);
    }

    /**
     * id 画布元素id
     * text 字码
     * color 颜色
     * x  字体x位置
     * y  字体y位置
     * fontSize 字体大小
     */
    draw(id, text, color, x, y, fontSize) {
        var dom = document.getElementById(id);
        var ctx = dom.getContext("2d");

        var stringText = String.fromCharCode(text);
        var path = this.font.getPath(stringText, x, y, fontSize);
        this.drawPathWithArrows(ctx, path, color);
    }

    drawPathWithArrows(ctx, path, color) {
        var i, cmd, x1, y1, x2, y2;
        var arrows = [];
        ctx.beginPath();
        for (i = 0; i < path.commands.length; i += 1) {
            cmd = path.commands[i];
            if (cmd.type === 'M') {
                if (x1 !== undefined) {
                    arrows.push([ctx, x1, y1, x2, y2]);
                }
                ctx.moveTo(cmd.x, cmd.y);
            } else if (cmd.type === 'L') {
                ctx.lineTo(cmd.x, cmd.y);
                x1 = x2;
                y1 = y2;
            } else if (cmd.type === 'C') {
                ctx.bezierCurveTo(cmd.x1, cmd.y1, cmd.x2, cmd.y2, cmd.x, cmd.y);
                x1 = cmd.x2;
                y1 = cmd.y2;
            } else if (cmd.type === 'Q') {
                ctx.quadraticCurveTo(cmd.x1, cmd.y1, cmd.x, cmd.y);
                x1 = cmd.x1;
                y1 = cmd.y1;
            } else if (cmd.type === 'Z') {
                arrows.push([ctx, x1, y1, x2, y2]);
                ctx.closePath();
            }
            x2 = cmd.x;
            y2 = cmd.y;
        }
        if (path.fill) {
            path.fill = color;
            ctx.fillStyle = path.fill;
            ctx.fill();
        }
        if (path.stroke) {
            path.stroke = color;
            ctx.strokeStyle = path.stroke;
            ctx.lineWidth = path.strokeWidth;
            ctx.stroke();
        }
    }

    /**
     * glyphIndex 图标索引
     * id 容器id
     * color 颜色
     * x 图标起始x坐标
     * y 图标起始y坐标
     * width 包含图标宽度
     * height 包含图标高度
     * size 图标大小
     */
    displayGlyph(glyphIndex, id, color, x, y, w, h, size) {

        var glyphMargin = 5,
            glyphW = w - glyphMargin * 2,
            glyphH = h - glyphMargin * 2,
            head = this.font.tables.head,
            maxHeight = head.yMax - head.yMin,
            glyphScale = Math.min(glyphW / (head.xMax - head.xMin), glyphH / maxHeight),
            glyphSize = glyphScale * this.font.unitsPerEm,
            glyphBaseline = glyphMargin + glyphH * head.yMax / maxHeight;

        var canvasCon = document.getElementById(id),
            canvas = document.createElement("canvas"),
            ctx = canvas.getContext('2d');

        canvas.style.cssText = "float:left";

        canvasCon.appendChild(canvas);

        //设置画布长宽
        canvas.width = canvasCon.offsetWidth / 3;
        canvas.height = canvasCon.offsetHeight;

        var width = canvas.offsetWidth;
        var height = canvas.offsetHeight;

        ctx.clearRect(0, 0, width, height);
        if (glyphIndex < 0) return;
        var glyph = this.font.glyphs.get(glyphIndex),
            glyphWidth = glyph.advanceWidth * glyphScale,
            xmin = (w - glyphWidth) / 2;

        ctx.fillStyle = color;
        ctx.fill();
        var path = glyph.getPath(xmin, y, size);

        console.log(glyphBaseline);
        path.fill = color;
        path.stroke = color;
        path.strokeWidth = 1.5;
        this.drawPathWithArrows(ctx, path, color);
    }
}

module.exports = MyFont;