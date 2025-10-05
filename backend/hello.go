package main

import (
	"fmt"
	"math/rand"
	"net/http"
	"os"
	"path/filepath"
	"time"
	"encoding/json"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

var (
	words = []string{
		"apple", "brave", "candy", "delta", "eagle",
		"flame", "grape", "house", "ivory", "jelly",
		"knife", "lemon", "mango", "noble", "ocean",
		"pearl", "queen", "river", "stone", "tiger",
		"unity", "vivid", "whale", "xenon", "young", "zebra",
	}
)
var uploadDir = "./uploads"

type FileMetadata struct {
    Checksum  string  `json:"checksum"`
    IV        string  `json:"iv"`
    Timestamp float64 `json:"timestamp"`
    FileName  string  `json:"fileName"`
    FileSize  int     `json:"fileSize"`
}

func main() {
	// Create uploads folder if not exists
	if _, err := os.Stat(uploadDir); os.IsNotExist(err) {
		os.Mkdir(uploadDir, os.ModePerm)
	}

	r := gin.Default()

	r.POST("/create-session", func(c *gin.Context) {

		rand.Seed(time.Now().UnixNano())
		word := words[rand.Intn(len(words))]

		fmt.Println("Random 5-letter word:", word)
		c.JSON(http.StatusOK, gin.H{
			"session_id": word,
		})

		dirName := fmt.Sprintf("./uploads/%s", word)
		err := os.Mkdir(dirName, 0755)
		print(err)
	})

	// Upload endpoint
	r.POST("/upload", func(c *gin.Context) {
		// Get session ID from form
		sessionID := c.PostForm("session_id")
		if sessionID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "session_id is required"})
			return
		}

		// Get session ID from form
		metadata_string := c.PostForm("metadata")
		var metadata FileMetadata
		err := json.Unmarshal([]byte(metadata_string), &metadata)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Parse uploaded file
		file := c.PostForm("file")
		if file == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "file is required"})
			return
		}

		// Create a folder for this session if it doesn't exist
		sessionDir := filepath.Join(uploadDir, sessionID)
		if err := os.MkdirAll(sessionDir, 0755); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		// Generate a unique ID for the file
		fileID := uuid.New().String()

		// Save file inside the session folder with its fileID
		savePath := filepath.Join(sessionDir, fileID)
		f, err := os.Create(savePath)
		if err != nil {
   			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer f.Close()
		f.WriteString(file)

		metaPath := filepath.Join(sessionDir, "meta.txt")
		mf, err := os.OpenFile(metaPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer mf.Close()
		mf.WriteString(fmt.Sprintf("%s: %s\n", fileID, metadata_string))

		c.JSON(http.StatusOK, gin.H{
 			"success":      true,
 			"message":      "File uploaded successfully",
 			"file_id":      fileID,
 			"download_url": fmt.Sprintf("http://localhost:8080/download/%s/%s", sessionID, sessionID),
        })
	})

	// Download endpoint
	r.GET("/download/:session_id/:filename", func(c *gin.Context) {
		sessionID := c.Param("session_id")
		filename := c.Param("filename")

		// Construct the full path to the file
		filePath := filepath.Join(uploadDir, sessionID, filename)

		// Check if the file exists
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			c.JSON(http.StatusNotFound, gin.H{"error": "file not found"})
			return
		}

		// Send the file as an attachment
		c.FileAttachment(filePath, filename)
	})

	r.GET("/get-all/:session_id", func(c *gin.Context) {
		sessionID := c.Param("session_id")
		sessionDir := filepath.Join(uploadDir, sessionID)

		metaPath := filepath.Join(sessionDir, "meta.txt")
		content, err := os.ReadFile(metaPath)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		fmt.Println(string(content))
		c.String(http.StatusOK, string(content))
	})

	// Start server
	fmt.Println("Server running on http://localhost:8000")
	r.Run(":8000")
}
