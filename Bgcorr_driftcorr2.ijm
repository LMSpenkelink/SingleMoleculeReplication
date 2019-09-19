//This code will do a background correction and xy-drift correction for all image files in a folder

sourceFolder = "L:/190913_1/"; //The folder that contains the data.


files = getFileList(sourceFolder); // Find all files in the source folder
CorrFolder="Corrected/"; //Foldername for kymographs
File.makeDirectory(sourceFolder + CorrFolder);// Create folder if it doesn't already exist.
run("Set Measurements...", "min redirect=None decimal=0"); // Set measurements to min & max gray value to 
LUTs=newArray("Grays", "Magenta","Green");
// We will open, correct, and save all individual fields of view.
for (i = 0; i < files.length;i++) {
	//Find the number of series in this file
	run("Bio-Formats Macro Extensions");
	Ext.setId(sourceFolder + files[i]);
	//Ext.getCurrentFile(file);
	Ext.getSeriesCount(seriesCount);
	for (s = 1; s < seriesCount+1;s++){   
    	series="series_"+s;
    	run("Bio-Formats", "open=" + sourceFolder+files[i] + " color_mode=Grayscale view=Hyperstack stack_order=XYCZT " + series);
    	rename("temp1");
    	getDimensions(w, h, channels, slices, frames); //find the number of colour channels and split them if there are more than 1.
    	if (channels==1){
    		rename("C1-temp1");
    	}
		else{
    		run("Split Channels");
		}
		
		//Background correction:
		for (c = 1; c <= channels; c++){
			Colour = "C"+c+"-temp1";
			selectWindow(Colour);
    		run("32-bit"); // change to 32 bit to allow for non-integer numbers after division.
    		
    		run("Z Project...", "projection=[Average Intensity]"); //this will be our background image used to correct for the beam profile.
    		run("Gaussian Blur...", "sigma=80");
    		run("Subtract...", "value=325"); // substract the dark count from the camera.
    		run("Measure");
        	max =(getResult("Max",0));
        	run("Divide...", "value=max"); // normalise the background image.
    		
    		selectWindow(Colour);
    		run("Subtract...", "value=325 stack"); // substract the dark count from the camera.
    		imageCalculator("Divide 32-bit stack", Colour,"AVG_"+Colour); // divide the movie by the normalised background image.
    		
    		selectWindow("AVG_"+Colour);
    		close(); //close the background image
    		
    		selectWindow(Colour);
    		setMinAndMax(0, 65535); // set display range to 16-bit compatible range
    		run("16-bit"); // change back to 16 bit.
    		
    		selectWindow("Results"); 
    		run("Close"); // close results window.
		}
       
		//Driftcorrection:
		//We will use the DNA channel to measure the drift, and then apply the same correction to all channels.
    	selectWindow("C1-temp1");
    	original = getImageID();
    	setBatchMode(true);
    	getSelectionBounds(sx, sy, sw, sh);
    	for (j = 2; j <= nSlices; j++) {
    		// First we calculate the Fourier transform of the first frame
        	selectImage(original);
        	setSlice(1);
        	makeRectangle(sx, sy, sw, sh);
        	run("FFT");
        	rename("a");
    		// Then calculate the FFT for slice j
        	selectImage(original);
        	setSlice(j);
        	makeRectangle(sx, sy, sw, sh);
        	run("FFT");
        	rename("b");
    		// calculate correlation
        	run("FD Math...", "image1=a operation=Correlate image2=b result=c do");
    
        	List.setMeasurements;
    
        	cx = getWidth / 2;
        	cy = getHeight / 2;
        	max = 0;
    
        	// the maximum should be somewhere in the center
        	for (y = cy - 100; y <= cy + 100; y++) {
            	for (x = cx - 100; x <= cx + 100; x++) {
                	pixel = getPixel(x, y);
                	if (pixel > max) {
                    	max = pixel;
                    	dx = x;
                    	dy = y;
                	}
            	}
        	}
    
        	dx -= cx; // drift in x direction
        	dy -= cy; // drift in y direction
        	setResult("dx", j-2, dx); // add dx and dy to results table
        	setResult("dy", j-2, dy); 
    
        	// close all temporary images
        	selectImage("a");
        	close();
        	selectImage("b");
        	close();
        	selectImage("c");
        	close();    
    	}
    	selectWindow("C1-temp1");
    	setBatchMode(false);
    	original = getImageID();
    	setBatchMode(true);
    	getSelectionBounds(sx, sy, sw, sh);
    	// Translate all slices 
    	for (j = 2; j <= nSlices; j++) {
        	selectImage(original);
        	setSlice(j);
        	run("Select All");
        	dx=getResult("dx", j-2);
        	dy=getResult("dy", j-2);
        	run("Translate...", "x=" + dx + " y=" + dy + " interpolation=Bilinear slice");
    	}
		setBatchMode(false);
		run(LUTs[0]);
		// If there are multiple channels, we will translate all slices in those channels by the same amount.
		if (channels>1){
			for (c = 2; c <= channels; c++){
				Colour = "C"+c+"-temp1";
				selectWindow(Colour);
    			setBatchMode(false);
    			original = getImageID();
    			setBatchMode(true);
    			getSelectionBounds(sx, sy, sw, sh);
    			for (j = 2; j <= nSlices; j++) {
        			selectImage(original);
        			setSlice(j);
        			run("Select All");
        			dx=getResult("dx", j-2);
        			dy=getResult("dy", j-2);
        			run("Translate...", "x=" + dx + " y=" + dy + " interpolation=Bilinear slice");
    			}
				setBatchMode(false);
				run(LUTs[c-1]);
			}
			// Merge all channels
			Merging ="";
			for (c = 1; c <= channels; c++){
				Merging=Merging+"c"+c+"=C"+c+"-temp1 ";
			}
    		run("Merge Channels...", Merging+" create");
		}
    	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel"); // Set scale to remove units
    	//Save the corrected movie
    	filename=("Corrected_"+files[i]);
    	saveAs("Tiff", sourceFolder + CorrFolder + "corrected_"+files[i]+"_"+series);
    	run("Close All");
	}
}
IJ.log("Finished!!");