var image_dir = 'large';
var images = [];
var current_image = 0;

function slideshow_init() {
    $("#slideshow").width(large_dimensions[0]);
    $("#slideshow").height(large_dimensions[1]);
    if ($("#slideshow").outerWidth() > $(window).width()
            || $("#slideshow").outerHeight() > $(window).height()) {
        image_dir = 'medium';
        $("#slideshow").width(medium_dimensions[0]);
        $("#slideshow").height(medium_dimensions[1]);
    }

    $("#slideshow_next").click(slideshow_next);
    $("#slideshow_prev").click(slideshow_prev);
    $("#slideshow_close").click(slideshow_stop);
    $("#slideshow_background").click(slideshow_stop);
}

function slideshow_start(image) {
    $("#slideshow_image").load(function() { 
        $("#slideshow").css('left', ($(window).width() - $("#slideshow").outerWidth())/2.0);
        $("#slideshow").css('top', ($(window).height() - $("#slideshow").outerHeight())/2.0);
        $("#slideshow, #slideshow_background").fadeIn('fast');
        $("#slideshow_background").css('z-index', '1');
    });

    slideshow_show(image);
}

function slideshow_stop() {
    $("#slideshow").fadeOut('fast', function() {
        $("#slideshow_image").removeAttr('src');
    });
    $("#slideshow_background").fadeOut('fast', function() {
        $(this).css('z-index', '-1');
    });

    document.location.hash = '';

    return false;
}

function slideshow_prev() {
    slideshow_show(current_image - 1); 
    return false;
}

function slideshow_next() {
    slideshow_show(current_image + 1); 
    return false;
}

function slideshow_show(image) {
    if (image < 0) {
        image = 0;
    } else if (image >= images.length) {
        image = images.length - 1;
    }

    current_image = image;
    $("#slideshow_image").attr('src', image_dir + "/" + images[image]);
    document.location.hash = 'slideshow=' + current_image;

    if (image >= images.length - 1)
        $("#slideshow_next").hide();
    else
        $("#slideshow_next").show();

    if (image <= 0)
        $("#slideshow_prev").hide();
    else
        $("#slideshow_prev").show();

    return false;
}

function basename(path) {
    return path.replace(/^.*[\/\\]/g, '');
} 
