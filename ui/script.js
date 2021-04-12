function realTimeLineChart() {
  var margin = {top: 20, right: 20, bottom: 60, left: 50},
      width = 600,
      height = 400,
      duration = 500,
      color = d3.schemeCategory10;

  function chart(selection) {
    // Based on https://bl.ocks.org/mbostock/3884955
    selection.each(function(data) {
      data = ["p", "t", "n"].map(function(c) {
        return {
          label: data[0].labels[c],
          values: data.map(function(d) {
            return {time: +d.time, value: d[c]};
          })
        };
      });

      var trans = d3.transition().duration(duration).ease(d3.easeLinear),
          vp = d3.scaleTime().rangeRound([0, width-margin.left-margin.right]),
          vt = d3.scaleLinear().rangeRound([height-margin.top-margin.bottom, 0]),
          vn = d3.scaleOrdinal(color);

      var xMin = d3.min(data, function(c) { return d3.min(c.values, function(d) { return d.time; })});
      var xMax = new Date(new Date(d3.max(data, function(c) {
        return d3.max(c.values, function(d) { return d.time; })
      })).getTime() - (duration*2));

      vp.domain([xMin, xMax]);
      vt.domain([
        d3.min(data, function(c) { return d3.min(c.values, function(d) { return d.value; })}),
        d3.max(data, function(c) { return d3.max(c.values, function(d) { return d.value; })})
      ]);
      vn.domain(data.map(function(c) { return c.label; }));

      var line = d3.line()
        .curve(d3.curveBasis)
        .x(function(d) { return vp(d.time); })
        .y(function(d) { return vt(d.value); });

      var svg = d3.select(this).selectAll("svg").data([data]);
      var gEnter = svg.enter().append("svg").append("g");
        gEnter.append("g").attr("class", "axis x");
        gEnter.append("g").attr("class", "axis y");
        gEnter.append("defs")
          .append("clipPath")
            .attr("id", "clip")
          .append("rect")
            .attr("width", width-margin.left-margin.right)
            .attr("height", height-margin.top-margin.bottom);
        gEnter.append("g")
            .attr("class", "lines")
            .attr("clip-path", "url(#clip)")
          .selectAll(".data").data(data).enter()
            .append("path")
              .attr("class", "data");

      var xAxisLabelEnter = gEnter.append("g")
        .attr("class", "label_x")
        .append('text')
          .attr("transform", "translate(" + ((width - margin.right - margin.right)/2) + " ," + (height - margin.bottom + 20) + ")")
          .style("text-anchor", "middle")
          .text('Time');
      var yAxisLabelEnter = gEnter.append("g")
        .attr("class", "label_y")
        .append('text')
          .attr("transform", "rotate(-90) translate(-" + ((height - margin.top - margin.bottom)/2) + " ,-" + (margin.left - 20) + ")")
          .style("text-anchor", "middle")
          .text('Change');

      var legendEnter = gEnter.append("g")
          .attr("class", "legend")
          .attr("transform", "translate(" + (width-margin.right-margin.left-200) + ",25)");
        legendEnter.append("rect")
          .attr("width", 200)
          .attr("height", 75)
          .attr("fill", "#ffffff")
          .attr("fill-opacity", 0.7);
        legendEnter.selectAll("text")
          .data(data).enter()
          .append("text")
            .attr("y", function(d, i) { return (i*20) + 25; })
            .attr("x", 5)
            .attr("fill", function(d) { return vn(d.label); });

      var svg = selection.select("svg");
      svg.attr('width', width).attr('height', height);
      var g = svg.select("g")
        .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

      g.select("g.axis.x")
        .attr("transform", "translate(0," + (height-margin.bottom-margin.top) + ")")
        .transition(trans)
        .call(d3.axisBottom(vp).ticks(5));
      g.select("g.axis.y")
        .transition(trans)
        .attr("class", "axis y")
        .call(d3.axisLeft(vt));

      g.select("defs clipPath rect")
        .transition(trans)
        .attr("width", width-margin.left-margin.right)
        .attr("height", height-margin.top-margin.right);

      g.selectAll("g path.data")
        .data(data)
        .style("stroke", function(d) { return vn(d.label); })
        .style("stroke-width", 1)
        .style("fill", "none")
        .transition()
        .duration(duration)
        .ease(d3.easeLinear)
        .on("start", tick);

      g.selectAll("g .legend text")
        .data(data)
        .text(function(d) {
          return d.label + ": " + d.values[d.values.length-1].value;
        });

      // For transitions https://bl.ocks.org/mbostock/1642874
      function tick() {
        d3.select(this)
          .attr("d", function(d) { return line(d.values); })
          .attr("transform", null);

        var xMinLess = new Date(new Date(xMin).getTime() - duration);
        d3.active(this)
            .attr("transform", "translate(" + vp(xMinLess) + ",0)")
          .transition()
            .on("start", tick);
      }
    });
  }

  chart.margin = function(_) {
    if (!arguments.length) return margin;
    margin = _;
    return chart;
  };

  chart.width = function(_) {
    if (!arguments.length) return width;
    width = _;
    return chart;
  };

  chart.height = function(_) {
    if (!arguments.length) return height;
    height = _;
    return chart;
  };

  chart.color = function(_) {
    if (!arguments.length) return color;
    color = _;
    return chart;
  };

  chart.duration = function(_) {
    if (!arguments.length) return duration;
    duration = _;
    return chart;
  };

  return chart;
}
