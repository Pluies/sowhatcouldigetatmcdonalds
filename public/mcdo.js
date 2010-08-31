$(document).ready(function(){
	initListeners();
});

function initListeners(){
	$(".amount").focus(function(){
		$(this).attr("value","$");
	});
	$(".mcdo_item").hover(
		function(e){
			$('.floatinfix').remove();
			$(this).addClass('hover');
		}, function(e){
			$(this).removeClass('hover');
			// Hide back the floatins'
			$(".floatin").remove();
		}
	);
	$(".mcdo_item").click(function(e){
			// Display I'm not lovin' it as a floatin'
			var itemNumber = $(this).attr('id').replace(/mcdo_(.*)/, '$1');
			var url = ''+window.location;
			if( url.match(/&without=/) )
				url = url + ',' + itemNumber;
			else
				url = url + "&without="+itemNumber;
			$(this.parentNode).append('<div class="floatin" style="top:'+(5+e.pageY)+'px;left:'+(5+e.pageX)+'px;" id="'+itemNumber+'"><a href='+url+' >I\'m not really lovin\' that</a></div>');
			// Fix the floatin' so it can be clicked (not beautiful, but will do)
			$(".floatin").attr('class', 'floatinfix' );
		});
}
