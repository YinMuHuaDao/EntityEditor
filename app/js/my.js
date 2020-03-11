let viewPortHeight = $(window).height();
let navHeight = $("#navbar").height();
let MainBodyHeight = viewPortHeight - navHeight;
let splitter = $("#MainBody")
  .height(MainBodyHeight)
  .split({
    orientation: "vertical",
    limit: {
      leftUpper: 400,
      rightBottom: 1000
    },
    position: "30%",
    // position: '50%', // if there is no percentage it interpret it as pixels
    onDrag: function (event) {
      console.log(splitter.position());
    }
  });

let splitters = $("#rightPane")
  .height(MainBodyHeight)
  .split({
    orientation: "vertical",
    limit: {
      leftUpper: 650,
      rightBottom: 300
    },
    position: "60%",
    onDrag: function (event) {
      console.log(splitters.position());
    }
  });