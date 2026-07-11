// ImageJ macro: batch pollen grain diameter measurement.
// Run in ImageJ with Plugins > Macros > Run...
//
// It uses one fixed scale-bar calibration for the whole batch, optionally
// detecting the red scale bar from the first image when no manual pixel value is given.
// It segments dark pollen grains, separates touching grains with watershed, filters
// circular black objects, calculates equivalent circular diameter from area, and
// rejects dark background interference using center-to-background contrast.
// A black-core-to-contour filter rejects grains with a continuous yellow outer ring.

requires("1.52");

function main() {
    arg = getArgument();
    if (arg != "") {
        parts = split(arg, "|");
        inputDir = ensureTrailingSlash(parts[0]);
        outputDir = ensureTrailingSlash(parts[1]);
        debugPath = outputDir + "pollen_debug_log.txt";
        if (File.exists(debugPath)) File.delete(debugPath);
        File.append("start batch arg=" + arg + "\n", debugPath);
        scaleKnownUm = parseFloat(parts[2]);
        File.append("scaleKnownUm=" + scaleKnownUm + "\n", debugPath);
        manualScalePx = 0;
        if (parts.length > 7) manualScalePx = parseFloat(parts[7]);
        File.append("manualScalePx=" + manualScalePx + "\n", debugPath);
        minDiamUm = parseFloat(parts[3]);
        File.append("minDiamUm=" + minDiamUm + "\n", debugPath);
        maxDiamUm = parseFloat(parts[4]);
        File.append("maxDiamUm=" + maxDiamUm + "\n", debugPath);
        thresholdMethod = parts[5];
        File.append("thresholdMethod=" + thresholdMethod + "\n", debugPath);
        savePreview = 0;
        if (parts[6] == "true") savePreview = 1;
        File.append("savePreview=" + savePreview + "\n", debugPath);
        runInBatch = 1;
        File.append("runInBatch=" + runInBatch + "\n", debugPath);
        redMin = 90;
        File.append("redMin=" + redMin + "\n", debugPath);
        greenMax = 130;
        blueMax = 130;
        searchRightPercent = 100;
        searchBottomPercent = 35;
        minScalePx = 20;
        circularityMin = 0.70;
        blackMaxIntensity = 90;
        minBlackCenterPercent = 95;
        minRoundness = 0.85;
        minSolidity = 0.94;
        minBackgroundContrast = 35;
        if (parts.length > 8) circularityMin = parseFloat(parts[8]);
        if (parts.length > 9) blackMaxIntensity = parseFloat(parts[9]);
        if (parts.length > 10) minBlackCenterPercent = parseFloat(parts[10]);
        if (parts.length > 11) minRoundness = parseFloat(parts[11]);
        if (parts.length > 12) minSolidity = parseFloat(parts[12]);
        if (parts.length > 13) minBackgroundContrast = parseFloat(parts[13]);
    } else {
        inputDir = getDirectory("Choose the pollen image folder");
        if (inputDir == "") exit("No input folder was selected.");
        outputDir = getDirectory("Choose the output folder");
        if (outputDir == "") exit("No output folder was selected.");

        Dialog.create("Pollen Diameter Batch");
        Dialog.addMessage("Fixed batch calibration. Set 'Scale bar length' to the number printed on your own image scale bar.");
        Dialog.addMessage("Example: if the image label says 50 um, enter 50. The macro detects the red line length, but it does not read the text label.");
        Dialog.addNumber("Scale bar length (um)", 100);
        Dialog.addNumber("Manual pixels for scale bar (0 = auto from first image)", 0);
        Dialog.addNumber("Valid diameter min (um)", 20);
        Dialog.addNumber("Valid diameter max (um)", 100);
        Dialog.addChoice("Auto threshold", newArray("Auto Best", "Otsu", "Default", "Huang", "Triangle", "Moments"), "Auto Best");
        Dialog.addNumber("Red threshold min", 90);
        Dialog.addNumber("Green max for red", 130);
        Dialog.addNumber("Blue max for red", 130);
        Dialog.addNumber("Search image width (%)", 100);
        Dialog.addNumber("Search bottom side (%)", 35);
        Dialog.addNumber("Minimum scale bar pixels", 20);
        Dialog.addNumber("Minimum circularity", 0.70);
        Dialog.addNumber("Minimum roundness", 0.85);
        Dialog.addNumber("Minimum solidity", 0.94);
        Dialog.addNumber("Black max intensity (RGB)", 90);
        Dialog.addNumber("Minimum black center (%)", 95);
        Dialog.addNumber("Minimum center-background contrast", 35);
        Dialog.addCheckbox("Save watershed preview PNG", 0);
        Dialog.addCheckbox("Run in batch mode", 1);
        Dialog.show();

        scaleKnownUm = Dialog.getNumber();
        manualScalePx = Dialog.getNumber();
        minDiamUm = Dialog.getNumber();
        maxDiamUm = Dialog.getNumber();
        thresholdMethod = Dialog.getChoice();
        redMin = Dialog.getNumber();
        greenMax = Dialog.getNumber();
        blueMax = Dialog.getNumber();
        searchRightPercent = Dialog.getNumber();
        searchBottomPercent = Dialog.getNumber();
        minScalePx = Dialog.getNumber();
        circularityMin = Dialog.getNumber();
        minRoundness = Dialog.getNumber();
        minSolidity = Dialog.getNumber();
        blackMaxIntensity = Dialog.getNumber();
        minBlackCenterPercent = Dialog.getNumber();
        minBackgroundContrast = Dialog.getNumber();
        savePreview = Dialog.getCheckbox();
        runInBatch = Dialog.getCheckbox();
        debugPath = outputDir + "pollen_debug_log.txt";
        if (File.exists(debugPath)) File.delete(debugPath);
        File.append("start dialog mode\n", debugPath);
        File.append("scaleKnownUm=" + scaleKnownUm + "\n", debugPath);
        File.append("manualScalePx=" + manualScalePx + "\n", debugPath);
        File.append("minDiamUm=" + minDiamUm + "\n", debugPath);
        File.append("maxDiamUm=" + maxDiamUm + "\n", debugPath);
        File.append("thresholdMethod=" + thresholdMethod + "\n", debugPath);
        File.append("redMin=" + redMin + "\n", debugPath);
        File.append("greenMax=" + greenMax + "\n", debugPath);
        File.append("blueMax=" + blueMax + "\n", debugPath);
        File.append("circularityMin=" + circularityMin + "\n", debugPath);
        File.append("minRoundness=" + minRoundness + "\n", debugPath);
        File.append("minSolidity=" + minSolidity + "\n", debugPath);
        File.append("blackMaxIntensity=" + blackMaxIntensity + "\n", debugPath);
        File.append("minBlackCenterPercent=" + minBlackCenterPercent + "\n", debugPath);
        File.append("minBackgroundContrast=" + minBackgroundContrast + "\n", debugPath);
    }

    File.append("circularityMin=" + circularityMin + "\n", debugPath);
    File.append("minRoundness=" + minRoundness + "\n", debugPath);
    File.append("minSolidity=" + minSolidity + "\n", debugPath);
    File.append("blackMaxIntensity=" + blackMaxIntensity + "\n", debugPath);
    File.append("minBlackCenterPercent=" + minBlackCenterPercent + "\n", debugPath);
    File.append("minBackgroundContrast=" + minBackgroundContrast + "\n", debugPath);
    File.append("outerYellowRingArcThresholdPercent=8\n", debugPath);
    File.append("settings loaded\n", debugPath);
    if (scaleKnownUm <= 0) exit("Scale bar length must be greater than 0.");
    if (minDiamUm <= 0 || maxDiamUm <= minDiamUm) exit("Diameter range is invalid.");
    if (circularityMin < 0 || circularityMin > 1) exit("Minimum circularity must be between 0 and 1.");
    if (minRoundness < 0 || minRoundness > 1) exit("Minimum roundness must be between 0 and 1.");
    if (minSolidity < 0 || minSolidity > 1) exit("Minimum solidity must be between 0 and 1.");
    if (blackMaxIntensity < 0 || blackMaxIntensity > 255) exit("Black max intensity must be between 0 and 255.");
    if (minBlackCenterPercent < 0 || minBlackCenterPercent > 100) exit("Minimum black center percent must be between 0 and 100.");
    if (minBackgroundContrast < 0 || minBackgroundContrast > 255) exit("Minimum center-background contrast must be between 0 and 255.");

    File.append("before batch mode\n", debugPath);
    if (runInBatch) setBatchMode(1);
    File.append("after batch mode\n", debugPath);

    tablePath = outputDir + "pollen_diameter_table.csv";
    particlesPath = outputDir + "pollen_particles_detail.csv";
    summaryPath = outputDir + "pollen_summary.csv";
    previewDir = outputDir + "pollen_previews/";

    if (File.exists(tablePath)) File.delete(tablePath);
    if (File.exists(particlesPath)) File.delete(particlesPath);
    if (File.exists(summaryPath)) File.delete(summaryPath);
    if (savePreview == 1 && File.exists(previewDir) == 0) File.makeDirectory(previewDir);

    File.append("Image,Particle_ID,Final_Status,Status_By_Area_Diameter,Status_By_Roundness,Status_By_Solidity,Status_By_Black_Filter,Status_By_Outer_Yellow_Ring,Status_By_Background_Contrast,Calibration_Mode,Threshold_Method,Area_um2,Diameter_from_area_um,Diameter_Feret_um,Circularity,Roundness,Solidity,X_um,Y_um,Black_Center_Percent,Yellow_Ring_Flagged_Angles_Percent,Yellow_Ring_Longest_Arc_Percent,Mean_R,Mean_G,Mean_B,Background_Mean_RGB,Center_Background_Contrast,ScaleBar_px,Um_per_px", particlesPath);
    File.append("Image,Image_Status,Calibration_Mode,Threshold_Method,ScaleBar_px,Um_per_px,Valid_Count_Fertile_Black,Invalid_Count_By_Diameter,Excluded_Count_By_Roundness,Excluded_Count_By_Solidity,Excluded_Count_By_Black_Filter,Excluded_Count_By_Outer_Yellow_Ring,Excluded_Count_By_Background_Contrast,Mean_Diameter_from_area_um,SD_Diameter_from_area_um,Min_Diameter_from_area_um,Max_Diameter_from_area_um", summaryPath);
    File.append("headers written\n", debugPath);

    list = getFileList(inputDir);
    File.append("file list length=" + list.length + "\n", debugPath);
    totalImages = countImageFiles(list);
    File.append("image file count=" + totalImages + "\n", debugPath);
    if (totalImages == 0) exit("No supported image files were found in the input folder.");

    fixedScalePx = manualScalePx;
    fixedCalibrationMode = "manual_fixed";
    if (manualScalePx > 0) {
        File.append("batch fixed scale source=manual px=" + fixedScalePx + "\n", debugPath);
    } else {
        fixedScalePx = getBatchScalePx(inputDir, list, redMin, greenMax, blueMax, searchRightPercent, searchBottomPercent, minScalePx);
        fixedCalibrationMode = "auto_fixed_first_image";
        File.append("batch fixed scale source=auto_first_image px=" + fixedScalePx + "\n", debugPath);
    }

    if (fixedScalePx < minScalePx) exit("Scale bar was not found. Enter a manual pixel length for the scale bar.");
    calibrationArg = d2s(scaleKnownUm, 6) + "," + d2s(fixedScalePx, 6) + "," + fixedCalibrationMode;
    filterArg = d2s(circularityMin, 6) + "," + d2s(blackMaxIntensity, 6) + "," + d2s(minBlackCenterPercent, 6) + "," + d2s(minRoundness, 6) + "," + d2s(minSolidity, 6) + "," + d2s(minBackgroundContrast, 6);

    processedImages = 0;
    maxValidCount = 0;
    imageNames = newArray(list.length);
    validCounts = newArray(list.length);
    tempPaths = newArray(list.length);

    for (i = 0; i < list.length; i++) {
        file = list[i];
        if (!isImageFile(file)) continue;
        showStatus("Processing " + file);
        File.append("processing " + file + "\n", debugPath);
        tempPath = outputDir + "__pollen_valid_" + processedImages + ".tmp";
        validRows = processOneImage(inputDir, outputDir, previewDir, file, processedImages, particlesPath, summaryPath, tempPath, calibrationArg, minDiamUm, maxDiamUm, thresholdMethod, redMin, greenMax, blueMax, searchRightPercent, searchBottomPercent, minScalePx, filterArg, savePreview);
        imageNames[processedImages] = stripExtension(file);
        validCounts[processedImages] = validRows;
        tempPaths[processedImages] = tempPath;
        if (validRows > maxValidCount) maxValidCount = validRows;
        File.append("processed " + file + "\n", debugPath);
        processedImages++;
    }

    writeWideDiameterTable(tablePath, imageNames, tempPaths, validCounts, processedImages, maxValidCount);
    for (i = 0; i < processedImages; i++) {
        if (File.exists(tempPaths[i])) File.delete(tempPaths[i]);
    }

    if (runInBatch) setBatchMode(0);
    showStatus("Done");
    print("Pollen diameter batch finished.");
    print("Images found: " + totalImages);
    print("Images processed: " + processedImages);
    print("Diameter table: " + tablePath);
    print("Particle detail table: " + particlesPath);
    print("Summary table: " + summaryPath);
}

function countImageFiles(list) {
    count = 0;
    for (i = 0; i < list.length; i++) {
        if (isImageFile(list[i])) count++;
    }
    return count;
}

function getBatchScalePx(inputDir, list, redMin, greenMax, blueMax, searchRightPercent, searchBottomPercent, minScalePx) {
    for (i = 0; i < list.length; i++) {
        file = list[i];
        if (!isImageFile(file)) continue;
        File.append("batch scale probe " + file + "\n", debugPath);
        open(inputDir + file);
        scaleInfo = split(findScaleBar(redMin, greenMax, blueMax, searchRightPercent, searchBottomPercent, minScalePx), ",");
        autoScalePx = parseFloat(scaleInfo[0]);
        File.append("batch scale probe result " + file + " px=" + autoScalePx + " x1=" + scaleInfo[1] + " x2=" + scaleInfo[2] + " y=" + scaleInfo[3] + "\n", debugPath);
        close();
        if (autoScalePx >= minScalePx) return autoScalePx;
    }
    return 0;
}

function chooseThresholdMethod(originalTitle, imageIndex, scalePx, scaleKnownUm, scaleX1, scaleX2, scaleY, width, height, minDiamUm, maxDiamUm, circularityMin, minRoundness, minSolidity) {
    methods = newArray("Otsu", "Default", "Huang");
    for (m = 0; m < methods.length; m++) {
        method = methods[m];
        plausibleCount = countPlausibleParticlesForThreshold(originalTitle, imageIndex, method, scalePx, scaleKnownUm, scaleX1, scaleX2, scaleY, width, height, minDiamUm, maxDiamUm, circularityMin, minRoundness, minSolidity);
        File.append("threshold probe method=" + method + " plausible=" + plausibleCount + "\n", debugPath);
        if (plausibleCount > 0) return method;
    }
    return "Default";
}

function countPlausibleParticlesForThreshold(originalTitle, imageIndex, method, scalePx, scaleKnownUm, scaleX1, scaleX2, scaleY, width, height, minDiamUm, maxDiamUm, circularityMin, minRoundness, minSolidity) {
    probeTitle = "Pollen_Threshold_Probe_" + imageIndex + "_" + method;
    selectWindow(originalTitle);
    run("Duplicate...", "title=[" + probeTitle + "]");
    selectWindow(probeTitle);
    run("Set Scale...", "distance=" + d2s(scalePx, 3) + " known=" + d2s(scaleKnownUm, 3) + " unit=um");
    clearScaleRegion(scaleX1, scaleX2, scaleY, width, height);

    run("8-bit");
    run("Enhance Contrast...", "saturated=0.35 normalize");
    setAutoThreshold(method + " dark");
    setOption("BlackBackground", 1);
    run("Convert to Mask");
    run("Invert");
    run("Fill Holes");
    run("Watershed");

    run("Set Measurements...", "area feret's shape display redirect=None decimal=3");
    run("Clear Results");
    candidateMinArea = PI * pow(minDiamUm / 2, 2) * 0.20;
    options = "size=" + d2s(candidateMinArea, 3) + "-Infinity circularity=" + d2s(circularityMin, 2) + "-1.00 display clear exclude";
    run("Analyze Particles...", options);

    plausibleCount = 0;
    for (r = 0; r < nResults; r++) {
        area = getResult("Area", r);
        areaDiameter = 2 * sqrt(area / PI);
        roundness = getResult("Round", r);
        solidity = getResult("Solidity", r);
        if (areaDiameter >= minDiamUm && areaDiameter <= maxDiamUm && roundness >= minRoundness && solidity >= minSolidity)
            plausibleCount++;
    }

    run("Clear Results");
    close();
    selectWindow(originalTitle);
    return plausibleCount;
}

function processOneImage(inputDir, outputDir, previewDir, file, imageIndex, particlesPath, summaryPath, tempPath, calibrationArg, minDiamUm, maxDiamUm, thresholdMethod, redMin, greenMax, blueMax, searchRightPercent, searchBottomPercent, minScalePx, filterArg, savePreview) {

    File.append("open " + file + "\n", debugPath);
    open(inputDir + file);
    originalTitle = getTitle();
    getDimensions(width, height, channels, slices, frames);
    calibrationParts = split(calibrationArg, ",");
    scaleKnownUm = parseFloat(calibrationParts[0]);
    fixedScalePx = parseFloat(calibrationParts[1]);
    fixedCalibrationMode = calibrationParts[2];
    filterParts = split(filterArg, ",");
    circularityMin = parseFloat(filterParts[0]);
    blackMaxIntensity = parseFloat(filterParts[1]);
    minBlackCenterPercent = parseFloat(filterParts[2]);
    minRoundness = parseFloat(filterParts[3]);
    minSolidity = parseFloat(filterParts[4]);
    minBackgroundContrast = parseFloat(filterParts[5]);

    File.append("find scale " + file + "\n", debugPath);
    scaleInfo = split(findScaleBar(redMin, greenMax, blueMax, searchRightPercent, searchBottomPercent, minScalePx), ",");
    autoScalePx = parseFloat(scaleInfo[0]);
    scaleX1 = parseFloat(scaleInfo[1]);
    scaleX2 = parseFloat(scaleInfo[2]);
    scaleY = parseFloat(scaleInfo[3]);
    scalePx = fixedScalePx;
    calibrationMode = fixedCalibrationMode;

    if (autoScalePx < minScalePx) {
        scaleX1 = floor(width * 0.78);
        scaleX2 = floor(width * 0.94);
        scaleY = floor(height * 0.88);
    }

    File.append("scale " + file + " mode=" + calibrationMode + " fixedPx=" + scalePx + " autoPx=" + autoScalePx + " x1=" + scaleX1 + " x2=" + scaleX2 + " y=" + scaleY + "\n", debugPath);

    if (scalePx < minScalePx) {
        File.append(csv(file) + ",scale_not_found,none,none,,,0,0,0,0,0,0,0,,,,", summaryPath);
        close();
        return 0;
    }

    umPerPx = scaleKnownUm / scalePx;
    actualThresholdMethod = thresholdMethod;
    if (thresholdMethod == "Auto Best") {
        actualThresholdMethod = chooseThresholdMethod(originalTitle, imageIndex, scalePx, scaleKnownUm, scaleX1, scaleX2, scaleY, width, height, minDiamUm, maxDiamUm, circularityMin, minRoundness, minSolidity);
        File.append("auto threshold selected " + file + " method=" + actualThresholdMethod + "\n", debugPath);
    }

    workTitle = "Pollen_Work_" + imageIndex;
    File.append("duplicate " + file + "\n", debugPath);
    run("Duplicate...", "title=[" + workTitle + "]");
    selectWindow(workTitle);
    run("Set Scale...", "distance=" + d2s(scalePx, 3) + " known=" + d2s(scaleKnownUm, 3) + " unit=um");

    clearScaleRegion(scaleX1, scaleX2, scaleY, width, height);

    File.append("threshold " + file + "\n", debugPath);
    run("8-bit");
    run("Enhance Contrast...", "saturated=0.35 normalize");
    setAutoThreshold(actualThresholdMethod + " dark");
    setOption("BlackBackground", 1);
    run("Convert to Mask");
    run("Invert");
    run("Fill Holes");
    run("Watershed");

    if (savePreview) {
        maskPreviewTitle = "Pollen_Mask_Preview_" + imageIndex;
        run("Duplicate...", "title=[" + maskPreviewTitle + "]");
        selectWindow(maskPreviewTitle);
        saveAs("PNG", previewDir + stripExtension(file) + "_mask.png");
        close();
        selectWindow(workTitle);
    }

    run("Set Measurements...", "area centroid perimeter feret's shape display redirect=None decimal=3");
    run("Clear Results");
    roiManager("Reset");

    candidateMinArea = PI * pow(minDiamUm / 2, 2) * 0.20;
    options = "size=" + d2s(candidateMinArea, 3) + "-Infinity circularity=" + d2s(circularityMin, 2) + "-1.00 display clear exclude add";
    if (savePreview)
        options = "size=" + d2s(candidateMinArea, 3) + "-Infinity circularity=" + d2s(circularityMin, 2) + "-1.00 show=Outlines display clear exclude add";
    File.append("analyze " + file + " options=" + options + "\n", debugPath);
    run("Analyze Particles...", options);
    File.append("analyze done " + file + " n=" + nResults + "\n", debugPath);

    if (savePreview) {
        outlineTitle = "Drawing of " + workTitle;
        if (isOpen(outlineTitle)) {
            selectWindow(outlineTitle);
            saveAs("PNG", previewDir + stripExtension(file) + "_outlines.png");
            close();
        }
        selectWindow(workTitle);
    }

    validCount = 0;
    invalidDiameterCount = 0;
    invalidRoundnessCount = 0;
    invalidSolidityCount = 0;
    nonblackCount = 0;
    outerYellowRingCount = 0;
    backgroundInterferenceCount = 0;
    sumDiam = 0;
    sumDiam2 = 0;
    minDiam = 1e30;
    maxDiam = -1;
    validRoiIndices = "";
    if (File.exists(tempPath)) File.delete(tempPath);

    for (r = 0; r < nResults; r++) {
        feret = getResult("Feret", r);
        area = getResult("Area", r);
        x = getResult("X", r);
        y = getResult("Y", r);
        circularity = getResult("Circ.", r);
        roundness = getResult("Round", r);
        solidity = getResult("Solidity", r);
        areaDiameter = 2 * sqrt(area / PI);

        statusAreaDiameter = "invalid";
        statusRoundness = "invalid";
        statusSolidity = "invalid";
        statusBlack = "nonblack";
        statusOuterYellowRing = "valid";
        statusBackground = "invalid";
        finalStatus = "invalid_diameter";
        if (areaDiameter >= minDiamUm && areaDiameter <= maxDiamUm) statusAreaDiameter = "valid";
        if (roundness >= minRoundness) statusRoundness = "valid";
        if (solidity >= minSolidity) statusSolidity = "valid";

        colorStats = split(getBlackCenterStats(originalTitle, workTitle, x, y, areaDiameter, umPerPx, blackMaxIntensity), ",");
        blackCenterPercent = parseFloat(colorStats[0]);
        meanR = parseFloat(colorStats[1]);
        meanG = parseFloat(colorStats[2]);
        meanB = parseFloat(colorStats[3]);
        if (blackCenterPercent >= minBlackCenterPercent) statusBlack = "black";

        yellowRingStats = split(getOuterYellowRingStats(originalTitle, workTitle, r, x, y, areaDiameter, umPerPx, blackMaxIntensity), ",");
        yellowRingFlaggedAnglesPercent = parseFloat(yellowRingStats[0]);
        yellowRingLongestArcPercent = parseFloat(yellowRingStats[1]);
        if (yellowRingLongestArcPercent >= 8) statusOuterYellowRing = "invalid";

        centerMean = (meanR + meanG + meanB) / 3;
        backgroundMean = getSurroundingBackgroundMean(originalTitle, workTitle, x, y, areaDiameter, umPerPx);
        backgroundContrast = backgroundMean - centerMean;
        if (backgroundContrast >= minBackgroundContrast) statusBackground = "valid";

        if (statusAreaDiameter == "valid" && statusRoundness == "valid" && statusSolidity == "valid" && statusBlack == "black" && statusOuterYellowRing == "valid" && statusBackground == "valid") {
            finalStatus = "valid";
            validCount++;
            sumDiam += areaDiameter;
            sumDiam2 += areaDiameter * areaDiameter;
            if (areaDiameter < minDiam) minDiam = areaDiameter;
            if (areaDiameter > maxDiam) maxDiam = areaDiameter;
            File.append(validCount + "," + d2s(area, 3) + "," + d2s(areaDiameter, 6), tempPath);
            validRoiIndices = validRoiIndices + r + "\n";
        } else if (statusAreaDiameter == "valid" && statusRoundness == "invalid") {
            finalStatus = "invalid_roundness";
            invalidRoundnessCount++;
        } else if (statusAreaDiameter == "valid" && statusSolidity == "invalid") {
            finalStatus = "invalid_solidity";
            invalidSolidityCount++;
        } else if (statusAreaDiameter == "valid" && statusBlack == "nonblack") {
            finalStatus = "nonblack";
            nonblackCount++;
        } else if (statusAreaDiameter == "valid" && statusOuterYellowRing == "invalid") {
            finalStatus = "outer_yellow_ring";
            outerYellowRingCount++;
        } else if (statusAreaDiameter == "valid") {
            finalStatus = "background_interference";
            backgroundInterferenceCount++;
        } else {
            invalidDiameterCount++;
        }

        File.append(csv(file) + "," + (r + 1) + "," + finalStatus + "," + statusAreaDiameter + "," + statusRoundness + "," + statusSolidity + "," + statusBlack + "," + statusOuterYellowRing + "," + statusBackground + "," + calibrationMode + "," + actualThresholdMethod + "," + d2s(area, 3) + "," + d2s(areaDiameter, 3) + "," + d2s(feret, 3) + "," + d2s(circularity, 3) + "," + d2s(roundness, 3) + "," + d2s(solidity, 3) + "," + d2s(x, 3) + "," + d2s(y, 3) + "," + d2s(blackCenterPercent, 3) + "," + d2s(yellowRingFlaggedAnglesPercent, 3) + "," + d2s(yellowRingLongestArcPercent, 3) + "," + d2s(meanR, 1) + "," + d2s(meanG, 1) + "," + d2s(meanB, 1) + "," + d2s(backgroundMean, 1) + "," + d2s(backgroundContrast, 1) + "," + d2s(scalePx, 3) + "," + d2s(umPerPx, 6), particlesPath);
    }

    if (savePreview) {
        saveFilteredWatershedPreview(workTitle, previewDir + stripExtension(file) + "_filtered_watershed.png", validRoiIndices, width, height);
        selectWindow(workTitle);
    }

    if (validCount > 0) {
        meanDiam = sumDiam / validCount;
        if (validCount > 1)
            sdDiam = sqrt((sumDiam2 - (sumDiam * sumDiam / validCount)) / (validCount - 1));
        else
            sdDiam = 0;
        File.append(csv(file) + ",ok," + calibrationMode + "," + actualThresholdMethod + "," + d2s(scalePx, 3) + "," + d2s(umPerPx, 6) + "," + validCount + "," + invalidDiameterCount + "," + invalidRoundnessCount + "," + invalidSolidityCount + "," + nonblackCount + "," + outerYellowRingCount + "," + backgroundInterferenceCount + "," + d2s(meanDiam, 3) + "," + d2s(sdDiam, 3) + "," + d2s(minDiam, 3) + "," + d2s(maxDiam, 3), summaryPath);
    } else {
        File.append(csv(file) + ",no_valid_particles," + calibrationMode + "," + actualThresholdMethod + "," + d2s(scalePx, 3) + "," + d2s(umPerPx, 6) + ",0," + invalidDiameterCount + "," + invalidRoundnessCount + "," + invalidSolidityCount + "," + nonblackCount + "," + outerYellowRingCount + "," + backgroundInterferenceCount + ",,,,", summaryPath);
    }

    run("Clear Results");
    roiManager("Reset");
    close();
    selectWindow(originalTitle);
    close();
    return validCount;
}

function getBlackCenterStats(originalTitle, workTitle, xUm, yUm, diameterUm, umPerPx, blackMaxIntensity) {
    xPx = xUm / umPerPx;
    yPx = yUm / umPerPx;
    diamPx = diameterUm / umPerPx;
    radius = maxOf(3, diamPx * 0.275);

    selectWindow(originalTitle);
    getDimensions(width, height, channels, slices, frames);

    x0 = maxOf(0, floor(xPx - radius));
    x1 = minOf(width - 1, floor(xPx + radius + 0.999));
    y0 = maxOf(0, floor(yPx - radius));
    y1 = minOf(height - 1, floor(yPx + radius + 0.999));

    rr = radius * radius;
    total = 0;
    dark = 0;
    sumR = 0;
    sumG = 0;
    sumB = 0;

    for (yy = y0; yy <= y1; yy++) {
        for (xx = x0; xx <= x1; xx++) {
            dx = xx - xPx;
            dy = yy - yPx;
            if (dx * dx + dy * dy <= rr) {
                v = getPixel(xx, yy);
                if (v < 0) v += 16777216;
                if (v <= 255) {
                    r = v;
                    g = v;
                    b = v;
                } else {
                    r = floor(v / 65536);
                    g = floor((v - r * 65536) / 256);
                    b = v - r * 65536 - g * 256;
                }

                total++;
                sumR += r;
                sumG += g;
                sumB += b;
                if (r <= blackMaxIntensity && g <= blackMaxIntensity && b <= blackMaxIntensity) dark++;
            }
        }
    }

    selectWindow(workTitle);
    if (total == 0) return "0,255,255,255";
    return "" + (100 * dark / total) + "," + (sumR / total) + "," + (sumG / total) + "," + (sumB / total);
}

function getOuterYellowRingStats(originalTitle, workTitle, roiIndex, xUm, yUm, diameterUm, umPerPx, blackMaxIntensity) {
    xPx = xUm / umPerPx;
    yPx = yUm / umPerPx;
    diamPx = diameterUm / umPerPx;
    angles = 72;
    maxRadius = floor(diamPx * 0.75);
    boundaries = newArray(angles);
    flags = newArray(angles);

    selectWindow(workTitle);
    roiManager("Select", roiIndex);
    for (a = 0; a < angles; a++) {
        theta = 2 * PI * a / angles;
        cosTheta = cos(theta);
        sinTheta = sin(theta);
        boundary = -1;
        seenParticle = 0;
        for (radius = 0; radius <= maxRadius; radius++) {
            xx = round(xPx + radius * cosTheta);
            yy = round(yPx + radius * sinTheta);
            inside = selectionContains(xx, yy);
            if (inside) {
                seenParticle = 1;
                boundary = radius;
            } else if (seenParticle) {
                radius = maxRadius + 1;
            }
        }
        boundaries[a] = boundary;
    }

    selectWindow(originalTitle);
    getDimensions(width, height, channels, slices, frames);
    flaggedAngles = 0;

    for (a = 0; a < angles; a++) {
        particleBoundary = boundaries[a];
        flags[a] = 0;
        if (particleBoundary < 4) continue;

        theta = 2 * PI * a / angles;
        cosTheta = cos(theta);
        sinTheta = sin(theta);
        blackCoreBoundary = 0;

        for (radius = 0; radius <= particleBoundary; radius++) {
            blackInWindow = 0;
            for (offset = -2; offset <= 2; offset++) {
                sampleRadius = radius + offset;
                if (sampleRadius < 0 || sampleRadius > particleBoundary) continue;
                xx = round(xPx + sampleRadius * cosTheta);
                yy = round(yPx + sampleRadius * sinTheta);
                if (xx < 0 || xx >= width || yy < 0 || yy >= height) continue;
                v = getPixel(xx, yy);
                if (v < 0) v += 16777216;
                if (v <= 255) {
                    red = v;
                    green = v;
                    blue = v;
                } else {
                    red = floor(v / 65536);
                    green = floor((v - red * 65536) / 256);
                    blue = v - red * 65536 - green * 256;
                }
                if (red <= blackMaxIntensity && green <= blackMaxIntensity && blue <= blackMaxIntensity)
                    blackInWindow++;
            }
            if (blackInWindow >= 3) blackCoreBoundary = radius;
        }

        ringStart = blackCoreBoundary + 1;
        ringThickness = particleBoundary - ringStart + 1;
        yellowCount = 0;
        longestYellowRun = 0;
        currentYellowRun = 0;

        for (radius = ringStart; radius <= particleBoundary; radius++) {
            xx = round(xPx + radius * cosTheta);
            yy = round(yPx + radius * sinTheta);
            if (xx < 0 || xx >= width || yy < 0 || yy >= height) continue;
            v = getPixel(xx, yy);
            if (v < 0) v += 16777216;
            if (v <= 255) {
                red = v;
                green = v;
                blue = v;
            } else {
                red = floor(v / 65536);
                green = floor((v - red * 65536) / 256);
                blue = v - red * 65536 - green * 256;
            }

            isYellow = 0;
            if (red - blue >= 20 && green - blue >= 5 && red >= 45 && green >= 35 && blue <= 150)
                isYellow = 1;
            if (isYellow) {
                yellowCount++;
                currentYellowRun++;
                if (currentYellowRun > longestYellowRun) longestYellowRun = currentYellowRun;
            } else {
                currentYellowRun = 0;
            }
        }

        if (ringThickness > 0) {
            if (ringThickness >= maxOf(3, diamPx * 0.04) &&
                longestYellowRun >= maxOf(2, diamPx * 0.025) &&
                yellowCount / ringThickness >= 0.45) {
                flags[a] = 1;
                flaggedAngles++;
            }
        }
    }

    longestAngleRun = 0;
    currentAngleRun = 0;
    for (i = 0; i < angles * 2; i++) {
        index = i;
        if (index >= angles) index = index - angles;
        if (flags[index] == 1) {
            currentAngleRun++;
            if (currentAngleRun > longestAngleRun) longestAngleRun = currentAngleRun;
        } else {
            currentAngleRun = 0;
        }
    }
    if (longestAngleRun > angles) longestAngleRun = angles;

    selectWindow(workTitle);
    return "" + (100 * flaggedAngles / angles) + "," + (100 * longestAngleRun / angles);
}

function getSurroundingBackgroundMean(originalTitle, workTitle, xUm, yUm, diameterUm, umPerPx) {
    xPx = xUm / umPerPx;
    yPx = yUm / umPerPx;
    diamPx = diameterUm / umPerPx;
    innerRadius = maxOf(4, diamPx * 0.60);
    outerRadius = maxOf(innerRadius + 2, diamPx * 0.85);

    selectWindow(originalTitle);
    getDimensions(width, height, channels, slices, frames);

    x0 = maxOf(0, floor(xPx - outerRadius));
    x1 = minOf(width - 1, floor(xPx + outerRadius + 0.999));
    y0 = maxOf(0, floor(yPx - outerRadius));
    y1 = minOf(height - 1, floor(yPx + outerRadius + 0.999));

    inner2 = innerRadius * innerRadius;
    outer2 = outerRadius * outerRadius;
    total = 0;
    sumIntensity = 0;

    for (yy = y0; yy <= y1; yy++) {
        for (xx = x0; xx <= x1; xx++) {
            dx = xx - xPx;
            dy = yy - yPx;
            dist2 = dx * dx + dy * dy;
            if (dist2 >= inner2 && dist2 <= outer2) {
                v = getPixel(xx, yy);
                if (v < 0) v += 16777216;
                if (v <= 255) {
                    r = v;
                    g = v;
                    b = v;
                } else {
                    r = floor(v / 65536);
                    g = floor((v - r * 65536) / 256);
                    b = v - r * 65536 - g * 256;
                }
                total++;
                sumIntensity += (r + g + b) / 3;
            }
        }
    }

    selectWindow(workTitle);
    if (total == 0) return 0;
    return sumIntensity / total;
}

function saveFilteredWatershedPreview(workTitle, previewPath, validRoiIndices, width, height) {
    previewTitle = "Pollen_Filtered_Watershed_Preview";
    if (isOpen(previewTitle)) {
        selectWindow(previewTitle);
        close();
    }

    newImage(previewTitle, "RGB white", width, height, 1);
    setLineWidth(1);
    setFont("SansSerif", 10, "bold");

    rows = split(validRoiIndices, "\n");
    for (i = 0; i < rows.length; i++) {
        row = replace(rows[i], "\r", "");
        if (lengthOf(row) == 0) continue;
        roiIndex = parseInt(row);
        selectWindow(workTitle);
        roiManager("Select", roiIndex);
        getSelectionCoordinates(xPoints, yPoints);
        getSelectionBounds(x, y, w, h);

        selectWindow(previewTitle);
        makeSelection("polygon", xPoints, yPoints);
        setForegroundColor(0, 0, 0);
        run("Draw");

        setColor(255, 0, 0);
        drawString("" + (roiIndex + 1), x + w / 2 - 4, y + h / 2 + 4);
    }

    run("Select None");
    saveAs("PNG", previewPath);
    close();
}

function findScaleBar(redMin, greenMax, blueMax, searchRightPercent, searchBottomPercent, minScalePx) {
    getDimensions(width, height, channels, slices, frames);
    xStart = floor(width * (100 - searchRightPercent) / 100);
    yStart = floor(height * (100 - searchBottomPercent) / 100);
    if (xStart < 0) xStart = 0;
    if (xStart >= width) xStart = floor(width * 0.5);
    if (yStart < 0) yStart = 0;
    if (yStart >= height) yStart = floor(height * 0.5);

    bestLen = 0;
    bestX1 = 0;
    bestX2 = 0;
    bestY = 0;
    bestScore = -1;
    maxGap = 3;

    for (y = yStart; y < height; y++) {
        runStart = -1;
        lastRed = -1;
        gap = 0;
        for (x = xStart; x < width; x++) {
            v = getPixel(x, y);
            if (v < 0) v += 16777216;
            r = floor(v / 65536);
            g = floor((v - r * 65536) / 256);
            b = v - r * 65536 - g * 256;

            isRed = 0;
            if (r >= redMin && g <= greenMax && b <= blueMax && r > g * 1.15 && r > b * 1.15) isRed = 1;
            if (isRed) {
                if (runStart < 0) runStart = x;
                lastRed = x;
                gap = 0;
            } else if (runStart >= 0) {
                gap++;
                if (gap > maxGap) {
                    len = lastRed - runStart + 1;
                    score = scoreScaleCandidate(runStart, lastRed, y, len, width, height, redMin, greenMax, blueMax, minScalePx);
                    if (score > bestScore) {
                        bestScore = score;
                        bestLen = len;
                        bestX1 = runStart;
                        bestX2 = lastRed;
                        bestY = y;
                    }
                    runStart = -1;
                    lastRed = -1;
                    gap = 0;
                }
            }
        }
        if (runStart >= 0) {
            len = lastRed - runStart + 1;
            score = scoreScaleCandidate(runStart, lastRed, y, len, width, height, redMin, greenMax, blueMax, minScalePx);
            if (score > bestScore) {
                bestScore = score;
                bestLen = len;
                bestX1 = runStart;
                bestX2 = lastRed;
                bestY = y;
            }
        }
    }
    return "" + bestLen + "," + bestX1 + "," + bestX2 + "," + bestY;
}

function scoreScaleCandidate(x1, x2, y, len, width, height, redMin, greenMax, blueMax, minScalePx) {
    if (len < minScalePx) return -1;
    if (hasScaleTicks(x1, x2, y, width, height, redMin, greenMax, blueMax))
        return height * 2000 + len * 10000 + y;
    return y * 10 + len;
}

function hasScaleTicks(x1, x2, y, width, height, redMin, greenMax, blueMax) {
    left = countVerticalRedNear(x1, y, width, height, redMin, greenMax, blueMax);
    right = countVerticalRedNear(x2, y, width, height, redMin, greenMax, blueMax);
    if (left >= 8 && right >= 8) return 1;
    return 0;
}

function countVerticalRedNear(x, y, width, height, redMin, greenMax, blueMax) {
    count = 0;
    y1 = maxOf(0, y - 5);
    y2 = minOf(height - 1, y + 30);
    x1 = maxOf(0, x - 4);
    x2 = minOf(width - 1, x + 4);
    for (yy = y1; yy <= y2; yy++) {
        found = 0;
        for (xx = x1; xx <= x2; xx++) {
            v = getPixel(xx, yy);
            if (v < 0) v += 16777216;
            r = floor(v / 65536);
            g = floor((v - r * 65536) / 256);
            b = v - r * 65536 - g * 256;
            if (r >= redMin && g <= greenMax && b <= blueMax && r > g * 1.15 && r > b * 1.15) found = 1;
        }
        if (found) count++;
    }
    return count;
}

function clearScaleRegion(scaleX1, scaleX2, scaleY, width, height) {
    scaleLength = maxOf(1, scaleX2 - scaleX1 + 1);
    padLeft = maxOf(20, scaleLength * 1.5);
    padRight = maxOf(12, scaleLength * 0.35);
    padTop = maxOf(28, scaleLength * 0.70);
    padBottom = maxOf(12, scaleLength * 0.30);

    x = maxOf(0, scaleX1 - padLeft);
    y = maxOf(0, scaleY - padTop);
    w = minOf(width - x, (scaleX2 - scaleX1 + 1) + padLeft + padRight);
    h = minOf(height - y, padTop + padBottom);

    setBackgroundColor(255, 255, 255);
    makeRectangle(x, y, w, h);
    run("Clear", "slice");
    run("Select None");
}

function isImageFile(name) {
    lower = toLowerCase(name);
    if (endsWith(lower, ".jpg")) return 1;
    if (endsWith(lower, ".jpeg")) return 1;
    if (endsWith(lower, ".png")) return 1;
    if (endsWith(lower, ".tif")) return 1;
    if (endsWith(lower, ".tiff")) return 1;
    if (endsWith(lower, ".bmp")) return 1;
    return 0;
}

function writeWideDiameterTable(tablePath, imageNames, tempPaths, validCounts, imageCount, maxValidCount) {
    header = "";
    for (i = 0; i < imageCount; i++) {
        header = header + csv(imageNames[i]) + ",Area_um2,Diameter_from_area_um,";
    }
    File.append(header, tablePath);

    for (row = 1; row <= maxValidCount; row++) {
        line = "";
        for (i = 0; i < imageCount; i++) {
            if (row <= validCounts[i])
                line = line + getTempDataRow(tempPaths[i], row) + ",";
            else
                line = line + ",,,";
        }
        File.append(line, tablePath);
    }
}

function getTempDataRow(path, targetRow) {
    if (File.exists(path) == 0) return ",,";
    text = File.openAsString(path);
    rows = split(text, "\n");
    seen = 0;
    for (j = 0; j < rows.length; j++) {
        line = replace(rows[j], "\r", "");
        if (lengthOf(line) == 0) continue;
        seen++;
        if (seen == targetRow) return line;
    }
    return ",,";
}

function stripExtension(name) {
    p = lastIndexOf(name, ".");
    if (p < 0) return name;
    return substring(name, 0, p);
}

function ensureTrailingSlash(path) {
    if (endsWith(path, "/")) return path;
    return path + "/";
}

function csv(s) {
    s = replace(s, ",", "_");
    return s;
}

main();
