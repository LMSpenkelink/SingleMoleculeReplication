sourceFolder = "L:/190826_5/"; //The folder that should contain the data.
Foldernames=newArray("DNAIntensities/", "Channel2/", "Channel3/"); //Names of the Folders that will be created dependin on the number of channels

PositionsFolder="Positions/"; //Foldername for position trajectories
KymoFolder="Kymographs/"; //Foldername for kymographs
File.makeDirectory(sourceFolder + PositionsFolder);// Create folder if it doesn't already exist.
File.makeDirectory(sourceFolder + KymoFolder);

//We will save the kymograph with the line.
kymoname = getTitle();
saveAs("Tiff", sourceFolder + KymoFolder + kymoname);
rename("kymo");
selectWindow("kymo");

//Then we will interpolate the points you added on the kymograph to get position information for every slice.
run("Properties... ", "list");//Get the coordinates for the points on the kymograph
selectWindow("XY_kymo");//Select the results table
IJ.renameResults("Results");//Rename it to Results
selectWindow("kymo");//Select the kymograph
run("Close");//Close the kymograph

getSelectionCoordinates(x, y);//Get the coordinates for the line on the movie
ypos=y[0];
x0=x[1];

X = newArray(nResults);
Y = newArray(nResults);
for (i = 0; i < X.length; i++){
	X[i] = getResult("X",i);
	Y[i] = getResult("Y",i);
}

selectWindow("Results"); 
run("Close"); 
// Now we will do the interpolation
for (i = 0; i < X.length-1; i++) {
	// For every interval we calculate the slope.
	intervalX = round(X[i+1]-X[i]);
	intervalY = round(Y[i+1]-Y[i]);
	slope = intervalY/intervalX;
	j=0;
	//For every slice we will calculate the Y position based on the local slope.
	for (j = round(X[i]); j < round(X[i+1]); j++) {
		setResult("slice",j,j);
		incr=j-X[i]+1;
		newY=Y[i]+slope*incr;
		setResult("Y",j,newY);
	}
}
// We will add the new slice, x, and y coordinates to a results table and the ROI manager
for (i = 0; i < nResults; i++) { 
    slice = getResult("slice", i); 
    x = x0-getResult("Y", i); // position of the line on the movie - the value found by interpolation from the kymograph
    y = ypos; //The same as the position of the line on the movie
    run("Specify...", "width=5 height=5 x=&x y=&y slice=&slice centered"); // Make a square ROI of size 5x5 pixels centered around the coordinate. 
    roiManager("Add"); // Add to the ROI manager. 
}

// Save the results table.
IJ.renameResults("Positions");
name = getTitle(); 
selectWindow("Positions");
saveAs("Results",sourceFolder+PositionsFolder + name +".xls");
run("Close");

// We need to know how many colour channels the movie has.
getDimensions(w, h, channels, slices, frames);
// For very channel we create a folder to save the intensity results tables in.
for(c = 0; c<channels; c++){
	File.makeDirectory(sourceFolder + Foldernames[c]); //create a folder if it doesn't already exist.
}
// If there are multible channels we need to split them.
if (channels==1){
    rename("C1-temp1");
}
else{
	rename("temp1");
    run("Split Channels");
}
run("Set Measurements...", "integrated redirect=None decimal=0");//Set measurements to calculate the integrated intensity.

// For every channel we will calculate the integrated intensity for the ROIs on every slice
for (c = 1; c <= channels; c++){
	Colour = "C"+c+"-temp1";
	selectWindow(Colour);//select the channel

	roiManager("Measure");// measure the intensity
	// For calculations done later, we need to add a trajectory and a slice column.
	for(r=0;r<nResults;r++){
		setResult("trajectory", r, 0);
		setResult("slice",r,r);
	}
	IJ.renameResults("peak"+c);//rename the results table
	roiManager("Deselect");
}

// To calculate the local background intensity we increase the size of the ROI.
n = roiManager("count");
for (i=0; i<n; i++) {
	roiManager("Select", i);
	getSelectionCoordinates(x, y);
	Roix=x[0];
	Roiy=y[0];
	slice=i;
	run("Specify...", "width=19 height=19 x=&Roix y=&Roiy slice=&slice centered"); // Make a square ROI of size 19x19 pixels at the same positions. 
	roiManager("Update");
}
roiManager("Deselect");
// For every channel we will calculate the integrated intensity for the background ROIs on every slice
for (c = 1; c <= channels; c++){
	Colour = "C"+c+"-temp1";
	selectWindow(Colour);
	roiManager("Measure");
	for(r=0;r<nResults;r++){
		setResult("trajectory", r, 0);
		setResult("slice",r,r);
	}
	IJ.renameResults("bg"+c);
	roiManager("Deselect");
}

// For every channel, we substract the background and save the tables with the corrected intensities.
for (c = 1; c <= channels; c++){
	run("Table Operations", "table_1=bg"+c+" column_1=IntDen trajectory_1=0 operation=subtract constant=0 table_2=peak"+c+" column_2=IntDen trajectory_2=0 new_column trajectory_number=2 column_name=bg");
	run("Table Operations", "table_1=bg"+c+" column_1=bg trajectory_1=0 operation=multiply use_constant constant=0.0693 table_2=peak"+c+" column_2=[ ] trajectory_2=0 new_column trajectory_number=2 column_name=bgPeak");
	run("Table Operations", "table_1=peak"+c+" column_1=IntDen trajectory_1=0 operation=subtract constant=0 table_2=bg"+c+" column_2=bgPeak trajectory_2=0 new_column trajectory_number=2 column_name=corrected_Int");

	//Close all windows for this channel
	selectWindow("peak"+c);
	saveAs("Results",sourceFolder+Foldernames[c-1] + name +".xls");
	selectWindow("bg"+c);
	run("Close");
	selectWindow(name+".xls");
	run("Close");
}

roiManager("Delete");//clear the ROI manager
run("Close All"); // close all open movies

IJ.log("Finished"); 
setTool("line"); // Set line tool back to line.
