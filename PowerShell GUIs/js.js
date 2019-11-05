function UpdateDriveStatus() {
    document.getElementById("bodypanel").innerHTML = "Updating...";
    var xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function() {
        if (this.readyState == 4 && this.status == 200) {
            document.getElementById("bodypanel").innerHTML = this.responseText;
        }
    };
    xhttp.open("GET", "http://localhost:8000/?action=drivestatus", true);
    xhttp.send();
}

function Stop() {
    document.getElementById("bodypanel").innerHTML = "Web Server Stopped";
    var xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function() {
        if (this.readyState == 4 && this.status == 200) {
            document.getElementById("bodypanel").innerHTML = this.responseText;
        }
    };
    xhttp.open("GET", "http://localhost:8000/?action=stop", true);
    xhttp.send();
}

function ShowVolume(id) {
    document.getElementById("DetailPanel").innerHTML = 'Updating...';
    var xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function() {
        if (this.readyState == 4 && this.status == 200) {
            document.getElementById("DetailPanel").innerHTML = this.responseText;
            document.getElementById("DetailPanel").style.visibility = 'visible';
        }
    };
    xhttp.open("GET", "http://localhost:8000/?action=diskinfo&VolumeId=" + id, true);
    xhttp.send();
}

function HideVolume() {
    document.getElementById("DetailPanel").style.visibility = 'hidden';
}