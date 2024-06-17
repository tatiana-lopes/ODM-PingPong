import processing.video.*;
import gab.opencv.*;
import org.opencv.core.Mat;
import java.util.ArrayList;
import java.util.HashSet;

Capture video;
OpenCV opencv;
PImage prevFrame;
ArrayList<Word> words;
HashSet<String> activeWords;
String[] wordList = {"DROIT", "PEACE", "NO AL RAZISMO", "SEXISME", "SHARE", "EGAL", "WOMANITY", "FEMINISM","EMIGRANT","RELATE","RE-USE","ACT","CO-DESIGN","CHANGE","SHARE"};
int maxWords = 30; // Maximum number of words
int minWords = 1; // Minimum number of words

int motionThresholdCount = 200; // Minimum number of pixels with motion to trigger a direction change
int motionSpeedThreshold = 1000; // Threshold for rapid motion
long lastMotionTime;
boolean isRemovingWords = false;
int wordCount = 1; // Initial number of words
long lastWordAddTime = 0; // Timer to delay word addition
int wordAddDelay = 1000; // Delay in milliseconds
color[] colorPalette = { #E0FC34 };
PFont jeanluc;

void setup() {
  //  fullScreen();
    size(1200, 800);
    video = new Capture(this, width, height);
    opencv = new OpenCV(this, width, height);
    video.start();
    prevFrame = createImage(width, height, RGB);
    words = new ArrayList<Word>();
    activeWords = new HashSet<String>();
    lastMotionTime = millis();
    jeanluc = loadFont("JeanLuc-Bold-48.vlw");
    textFont(jeanluc);
  //  addWord(getRandomWord(), width / 2, height / 2);
}

void draw() {
    if (video.available()) {
        video.read();
        opencv.loadImage(video);
        
        // Display video feed
        image(video, 0, 0);
        background(#003FFF);
      
        // Draw the dividing vertical and horizontal lines
        stroke(255, 255, 255);
        line(width / 2, 0, width / 2, height);
        strokeWeight(3);
        line(0, height / 2, width, height / 2);
        strokeWeight(8);
        // Convert current frame to grayscale
        PImage currFrame = video.get();
        currFrame.filter(GRAY);

        // Compute the difference between the current frame and the previous frame
        PImage diff = createImage(width, height, RGB);
        diff.loadPixels();
        currFrame.loadPixels();
        prevFrame.loadPixels();
        for (int i = 0; i < diff.pixels.length; i++) {
            int diffValue = abs(currFrame.pixels[i] - prevFrame.pixels[i]);
            diff.pixels[i] = color(diffValue);
        }
        diff.updatePixels();

        // Detect motion on the left or right side
        int leftMotionCount = 0;
        int rightMotionCount = 0;
        int threshold = 50; // Motion sensitivity threshold
        
        diff.loadPixels();
        for (int y = 0; y < height; y++) {
            // Inverted motion detection ranges because the camera inverts the motion sides.
            for (int x = width / 2; x < width; x++) {
                if (brightness(diff.pixels[y * width + x]) > threshold) {
                    leftMotionCount++;
                }
            }
            for (int x = 0; x < width / 2; x++) {
                if (brightness(diff.pixels[y * width + x]) > threshold) {
                    rightMotionCount++;
                }
            }
        }

        // Adjust word count based on motion detection
        int totalMotionCount = leftMotionCount + rightMotionCount;
        if (totalMotionCount > motionSpeedThreshold) {
            wordCount = min(maxWords, wordCount + 1);
            lastMotionTime = millis();
            isRemovingWords = false;
        } else if (totalMotionCount > motionThresholdCount) {
            if (millis() - lastWordAddTime > wordAddDelay) {
                wordCount = min(maxWords, wordCount + 1); 
                lastMotionTime = millis();
                isRemovingWords = false;
                lastWordAddTime = millis();
            }
        } else {
            if (millis() - lastMotionTime > 5000) {
                isRemovingWords = true; // Start removing words after 5 seconds of no motion
            }
        }

        // Gradually remove words if there is no motion
        if (isRemovingWords && frameCount % 60 == 0 && words.size() > minWords) {
            String removedWord = words.remove(words.size() - 1).text;
            activeWords.remove(removedWord);
            wordCount--; // Decrease the word count to ensure only one word is left gradually
        }

        // Add words to match the desired word count with a delay when no words are being removed
        if (!isRemovingWords) {
            while (words.size() < wordCount) {
                if (millis() - lastWordAddTime > wordAddDelay) {
                    String newWord = getRandomWord();
                    float x, y;
                    if (leftMotionCount > rightMotionCount) {
                        x = random(0, width / 2); // Place the word on the left side
                    } else {
                        x = random(width / 2, width); // Place the word on the right side
                    }
                    y = random(0, height); // Initial position randomly within the height
                    addWord(newWord, x, y);
                    lastWordAddTime = millis();
                } else {
                    break;
                }
            }
        }

        // Update and draw words
        for (Word word : words) {
            word.update(leftMotionCount > rightMotionCount); // true if left motion is greater
        }

        // Save the current frame as the previous frame for the next iteration
        prevFrame.copy(currFrame, 0, 0, width, height, 0, 0, width, height);
        
        // Reset motion counts
        leftMotionCount = 0;
        rightMotionCount = 0;
    }
}

void addWord(String text, float x, float y) {
    words.add(new Word(text, x, y));
    activeWords.add(text);
}

String getRandomWord() {
    ArrayList<String> availableWords = new ArrayList<String>();
    for (String word : wordList) {
        if (!activeWords.contains(word)) {
            availableWords.add(word);
        }
    }
    if (availableWords.isEmpty()) {
        int randomNr = int(random(wordList.length));
        return wordList[randomNr];
    }
    return availableWords.get(int(random(availableWords.size())));
}

class Word {
    PVector position;
    PVector velocity;
    PVector originalVelocity; 
    float rotationAngle;
    float rotationSpeed;
    float maxRotationAngle;
    float maxRotationSpeed;
    String text;
    color wordColor;
    float fontSize;
    float velocityMultiplier; // Multiplier to adjust velocity based on font size
    float initialVelocityMag; // Initial velocity magnitude based on font size
   
    Word(String text, float x, float y) {
        this.text = text;
        this.position = new PVector(x, y);
        this.rotationAngle = 0;
        this.rotationSpeed = 0.01;
        this.maxRotationSpeed = 0.1; 
        this.maxRotationAngle = PI / 4; 
        this.wordColor = #E0FC34;
        this.fontSize = random(30,60);
        this.initialVelocityMag = map(this.fontSize, 30, 60, 5, 1); // Map font size to initial velocity magnitude
        this.velocity = PVector.random2D().mult(initialVelocityMag);
      
    }

    void update(boolean isLeftMotion) {
        // Update position
        position.add(velocity);
        float textHalfWidth = textWidth(text) / 2;
        float textHalfHeight = textAscent() / 2;
        float margin = 5; // Small margin to prevent words from getting stuck
        
        if (position.x - textHalfWidth <= margin) {
            position.x = textHalfWidth + margin;
            fontSize = random(30, 60);
            initialVelocityMag = map(fontSize, 30, 60, 3, 1);
            velocity.setMag(initialVelocityMag);
            velocity.x *= -1;
            velocity.mult(1.02); // Speed up velocity after bounce
            rotationSpeed += 0.02; // Increase rotation speed
            fontSize = random(30,60);
            
        } else if (position.x + textHalfWidth >= width - margin) {
            position.x = width - textHalfWidth - margin;
            fontSize = random(30, 60);
            initialVelocityMag = map(fontSize, 30, 60, 3, 1);
            velocity.setMag(initialVelocityMag);
            velocity.x *= -1;
            velocity.mult(1.02); // Speed up velocity after bounce
            rotationSpeed += 0.02; // Increase rotation speed
        }
        
        if (position.y - textHalfHeight <= margin) {
            position.y = textHalfHeight + margin;
            fontSize = random(30, 60);
            initialVelocityMag = map(fontSize, 30, 60, 3, 1);
            velocity.setMag(initialVelocityMag);
            velocity.y *= -1;
            velocity.mult(1.02); // Speed up velocity after bounce
            rotationSpeed += 0.02; // Increase rotation speed
             fontSize = random(30,60);
        } 
        else if (position.y + textHalfHeight >= height - margin) {
            position.y = height - textHalfHeight - margin; 
             fontSize = random(30, 60);
            initialVelocityMag = map(fontSize, 30, 60, 3, 1);
            velocity.setMag(initialVelocityMag);
            velocity.y *= -1;
            velocity.mult(1.02); // Speed up velocity after bounce
            rotationSpeed += 0.02; // Increase rotation speed
             fontSize = random(30,60);
        }

        // Adjust velocity based on motion detection
        if (isLeftMotion && position.x < (width / 2) -150) {  //  middle of the left side
            velocity.x = abs(velocity.x); // Ensure moving right
            velocity.mult(1.05); // Speed up velocity
          
        }
        if (!isLeftMotion && position.x > (width /2) + 150) { //  middle of the right side
            velocity.x = -abs(velocity.x);
            velocity.mult(1.05);
      
        }
        // maximum rotation speed limit
        rotationSpeed = constrain(rotationSpeed, 0, maxRotationSpeed);
        
        // maximum velocity limit  
        float maxVelocity = 4; // Maximum speed for the velocity
        if (velocity.mag() > maxVelocity) {
            
            velocity.setMag(initialVelocityMag);
        }
        
        // Rotate the word
        rotationAngle += rotationSpeed;
        // Slow down rotation speed back to the initial value
        if (rotationSpeed > 0.01) { // if rotation speed is greater than initial value
            rotationSpeed -= 0.002; // Decrease rotation speed gradually
        }
           
        fill(wordColor);
        pushMatrix();
        translate(position.x + textWidth(text) / 2, position.y - textAscent() / 2);
        rotate(rotationAngle);
        textAlign(CENTER, CENTER);
        textSize(fontSize);
        text(text, 0, 0);
        popMatrix();
    }
}
