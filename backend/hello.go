package main

import (
	"fmt"
	"math/rand"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/gin-gonic/gin"
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

		// Parse uploaded file
		file, err := c.FormFile("file")
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Create a folder for this session if it doesn't exist
		sessionDir := filepath.Join(uploadDir, sessionID)
		if err := os.MkdirAll(sessionDir, 0755); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		// Save file inside the session folder with its original name
		savePath := filepath.Join(sessionDir, file.Filename)
		if err := c.SaveUploadedFile(file, savePath); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"session_id": sessionID,
			"filename":   file.Filename,
			"path":       savePath,
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

		dirPath := filepath.Join(uploadDir, sessionID)

		entries, err := os.ReadDir(dirPath)
		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}

		// Extract filenames
		var filenames []string
		for _, entry := range entries {
			if !entry.IsDir() {
				filenames = append(filenames, entry.Name())
			}
		}

		// Return JSON array
		c.JSON(200, gin.H{
			"session_id": sessionID,
			"files":      filenames,
		})
	})

	// Start server
	fmt.Println("Server running on http://localhost:8080")
	r.Run(":8080")
}
