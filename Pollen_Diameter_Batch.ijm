// ImageJ macro: batch pollen grain diameter measurement.
// Run in ImageJ with Plugins > Macros > Run...
//
// It uses one fixed scale-bar calibration for the whole batch, optionally
// detecting the red scale bar from the first image when no manual pixel value is given.
// It segments dark pollen grains, separates touching grains with watershed, filters diameters
// outside the configured micrometer range, and writes Excel-readable CSV files.

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
        searchRightPercent = 40;
        searchBottomPercent = 35;
        minScalePx = 20;
        circularityMin = 0.70;
        blackMaxIntensity = 90;
        minBlackCenterPercent = 95;
        if (parts.length > 8) circularityMin = parseFloat(parts[8]);
        if (parts.length > 9) blackMaxIntensity = parseFloat(parts[9]);
        if (parts.length > 10) minBlackCenterPercent = parseFloat(parts[10]);
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
        Dialog.addChoice("Auto threshold", newArray("Default", "Otsu", "Triangle", "Moments", "Huang"), "Default");
        Dialog.addNumber("Red threshold min", 90);
        Dialog.addNumber("Green max for red", 130);
        Dialog.addNumber("Blue max for red", 130);
        Dialog.addNumber("Search right side (%)", 40);
        Dialog.addNumber("Search bottom side (%)", 35);
        Dialog.addNumber("Minimum scale bar pixels", 20);
        Dialog.addNumber("Minimum circularity", 0.70);
        Dialog.addNumber("Black max intensity (RGB)", 90);
        Dialog.addNumber("Minimum black center (%)", 95);
        Dialog.addCheckbox("Save outline preview PNG", 0);
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
        blackMaxIntensity = Dialog.getNumber();
        minBlackCenterPercent = Dialog.getNumber();
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
        File.append("blackMaxIntensity=" + blackMaxIntensity + "\n", debugPath);
        File.append("minBlackCenterPercent=" + minBlackCenterPercent + "\n", debugPath);
    }

    File.append("circularityMin=" + circularityMin + "\n", debugPath);
    File.append("blackMaxIntensity=" + blackMaxIntensity + "\n", debugPath);
    File.append("minBlackCenterPercent=" + minBlackCenterPercent + "\n", debugPath);
    File.append("settings loaded\n", debugPath);
    if (scaleKnownUm <= 0) exit("Scale bar length must be greater than 0.");
    if (minDiamUm <= 0 || maxDiamUm <= minDiamUm) exit("Diameter range is invalid.");
    if (circularityMin < 0 || circularityMin > 1) exit("Minimum circularity must be between 0 and 1.");
    if (blackMaxIntensity < 0 || blackMaxIntensity > 255) exit("Black max intensity must be between 0 and 255.");
    if (minBlackCenterPercent < 0 || minBlackCenterPercent > 100) exit("Minimum black center percent must be between 0 and 100.");

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

    File.append("Image,Particle_ID,Final_Status,Status_By_Area_Diameter,Status_By_Feret_Diameter,Status_By_Black_Filter,Calibration_Mode,Area_um2,Diameter_From_Area_um,Diameter_Feret_um,X_um,Y_um,Black_Center_Percent,Mean_R,Mean_G,Mean_B,ScaleBar_px,Um_per_px", particlesPath);
    File.append("Image,Image_Status,Calibration_Mode,ScaleBar_px,Um_per_px,Valid_Count_Fertile_Black,Invalid_Count_By_Diameter,Excluded_Count_By_Black_Filter,Mean_Diameter_From_Area_um,SD_Diameter_From_Area_um,Min_Diameter_From_Area_um,Max_Diameter_From_Area_um", summaryPath);
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
    filterArg = d2s(circularityMin, 6) + "," + d2s(blackMaxIntensity, 6) + "," + d2s(minBlackCenterPercent, 6);

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
        File.append(csv(file) + ",scale_not_found,none,,,,,,,,,", summaryPath);
        close();
        return 0;
    }

    umPerPx = scaleKnownUm / scalePx;
    workTitle = "Pollen_Work_" + imageIndex;
    File.append("duplicate " + file + "\n", debugPath);
    run("Duplicate...", "title=[" + workTitle + "]");
    selectWindow(workTitle);
    run("Set Scale...", "distance=" + d2s(scalePx, 3) + " known=" + d2s(scaleKnownUm, 3) + " unit=um");

    clearScaleRegion(scaleX1, scaleX2, scaleY, width, height);

    File.append("threshold " + file + "\n", debugPath);
    run("8-bit");
    run("Enhance Contrast...", "saturated=0.35 normalize");
    setAutoThreshold(thresholdMethod + " dark");
    setOption("BlackBackground", 1);
    run("Convert to Mask");
    run("Invert");
    run("Fill Holes");
    run("Watershed");

    run("Set Measurements...", "area centroid perimeter feret's shape display redirect=None decimal=3");
    run("Clear Results");

    candidateMinArea = PI * pow(minDiamUm / 2, 2) * 0.20;
    options = "size=" + d2s(candidateMinArea, 3) + "-Infinity circularity=" + d2s(circularityMin, 2) + "-1.00 display clear exclude";
    if (savePreview)
        options = "size=" + d2s(candidateMinArea, 3) + "-Infinity circularity=" + d2s(circularityMin, 2) + "-1.00 show=Outlines display clear exclude";
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
    nonblackCount = 0;
    sumDiam = 0;
    sumDiam2 = 0;
    minDiam = 1e30;
    maxDiam = -1;
    if (File.exists(tempPath)) File.delete(tempPath);

    for (r = 0; r < nResults; r++) {
        feret = getResult("Feret", r);
        area = getResult("Area", r);
        x = getResult("X", r);
        y = getResult("Y", r);
        eqDiam = 2 * sqrt(area / PI);

        statusArea = "invalid";
        statusFeret = "invalid";
        statusBlack = "nonblack";
        finalStatus = "invalid_diameter";
        if (feret >= minDiamUm && feret <= maxDiamUm) statusFeret = "valid";
        if (eqDiam >= minDiamUm && eqDiam <= maxDiamUm) statusArea = "valid";

        colorStats = split(getBlackCenterStats(originalTitle, workTitle, x, y, eqDiam, umPerPx, blackMaxIntensity), ",");
        blackCenterPercent = parseFloat(colorStats[0]);
        meanR = parseFloat(colorStats[1]);
        meanG = parseFloat(colorStats[2]);
        meanB = parseFloat(colorStats[3]);
        if (blackCenterPercent >= minBlackCenterPercent) statusBlack = "black";

        if (statusArea == "valid" && statusBlack == "black") {
            finalStatus = "valid";
            validCount++;
            sumDiam += eqDiam;
            sumDiam2 += eqDiam * eqDiam;
            if (eqDiam < minDiam) minDiam = eqDiam;
            if (eqDiam > maxDiam) maxDiam = eqDiam;
            File.append(validCount + "," + d2s(area, 3) + "," + d2s(eqDiam, 6), tempPath);
        } else if (statusArea == "valid") {
            finalStatus = "nonblack";
            nonblackCount++;
        } else {
            invalidDiameterCount++;
        }

        File.append(csv(file) + "," + (r + 1) + "," + finalStatus + "," + statusArea + "," + statusFeret + "," + statusBlack + "," + calibrationMode + "," + d2s(area, 3) + "," + d2s(eqDiam, 6) + "," + d2s(feret, 3) + "," + d2s(x, 3) + "," + d2s(y, 3) + "," + d2s(blackCenterPercent, 3) + "," + d2s(meanR, 1) + "," + d2s(meanG, 1) + "," + d2s(meanB, 1) + "," + d2s(scalePx, 3) + "," + d2s(umPerPx, 6), particlesPath);
    }

    if (validCount > 0) {
        meanDiam = sumDiam / validCount;
        if (validCount > 1)
            sdDiam = sqrt((sumDiam2 - (sumDiam * sumDiam / validCount)) / (validCount - 1));
        else
            sdDiam = 0;
        File.append(csv(file) + ",ok," + calibrationMode + "," + d2s(scalePx, 3) + "," + d2s(umPerPx, 6) + "," + validCount + "," + invalidDiameterCount + "," + nonblackCount + "," + d2s(meanDiam, 3) + "," + d2s(sdDiam, 3) + "," + d2s(minDiam, 3) + "," + d2s(maxDiam, 3), summaryPath);
    } else {
        File.append(csv(file) + ",no_valid_particles," + calibrationMode + "," + d2s(scalePx, 3) + "," + d2s(umPerPx, 6) + ",0," + invalidDiameterCount + "," + nonblackCount + ",,,,", summaryPath);
    }

    run("Clear Results");
    close();
    selectWindow(originalTitle);
    close();
    return validCount;
}

function getBlackCenterStats(originalTitle, workTitle, xUm, yUm, eqDiamUm, umPerPx, blackMaxIntensity) {
    xPx = xUm / umPerPx;
    yPx = yUm / umPerPx;
    diamPx = eqDiamUm / umPerPx;
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
    padLeft = 140;
    padRight = 70;
    padTop = 85;
    padBottom = 45;

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
