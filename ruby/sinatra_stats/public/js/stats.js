
$(document).ready(function() {

$('#chart_data').hide();

var chart_data = JSON.parse( $('#chart_data').text() );

    // Set default options
    Highcharts.setOptions({ 
      chart: {
      renderTo: 'chart',
      defaultSeriesType: 'area',
      margin: [, 0, 20, 35],
      height: 250
      },
      title: {
        text: ''
      },
      yAxis: {
        alternateGridColor: null,
        minorTickInterval: null,
        lineWidth: 0,
        tickWidth: 0,
        min: 0,
        title: {
           text: null
        }
      },
      legend: {
//     layout: 'vertical',
//     enabled: false,
        backgroundColor: '#ffffff',
        style: {
          left: '15px',
          bottom: 'auto',
          top: '5px'
        }
      },
      tooltip: {
        formatter: function() {
          return this.y ;
        },
        backgroundColor: {
          linearGradient: [0, 0, 0, 50],
          stops: [[0, 'rgba(66, 60, 50, .9)'],
                  [1, 'rgba(29, 27, 21, .8)']]
        },
        borderWidth: 0,
        style: {
          color: '#FFF'
        }
      },
      plotOptions: {
//      column: {
//         pointPadding: 0.2,
//         borderWidth: 0
//      }
//        area: {
//          fillOpacity: 0.5
//        },
        area: {
          fillColor: {
             linearGradient: [0, 0, 0, 300],
             stops: [
                [0, '#058DC7'],
                [1, 'rgba(2,0,0,0)']
             ]
          },
          lineWidth: 1,
          marker: {
             enabled: false,
             states: {
                hover: {
                   enabled: true,
                   radius: 5
                }
             }
          },
          shadow: false,
          states: {
             hover: {
                lineWidth: 1                  
             }
          }
        }
      },
      credits:{enabled: false}
    });

  var chart = new Highcharts.Chart({
    chart: {
      renderTo: 'chart',
       zoomType: 'x',
      defaultSeriesType: 'area'
    },
    xAxis: {
       type: 'datetime',
       maxZoom: 7 * 24 * 3600000 // fourteen days
       //categories: chart_data.lbx
    },
    series: [{ type: 'area',
        //name: 'Data',
        //one day in milliseconds
        pointInterval: 24 * 3600 * 1000, 
        pointStart: Date.UTC(chart_data.start[0], chart_data.start[1], chart_data.start[2]),
        data: chart_data.data }]
  });







});


