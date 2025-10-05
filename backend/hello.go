package main

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"net/http"
	"os"
	"errors"
	"path/filepath"
	"sync"
	"time"
	"strings"
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

	uploadDir = "./uploads"

	// logs store
	logs     []string
	logsLock sync.Mutex
)

// FileMetadata structure
type FileMetadata struct {
	Checksum  string  `json:"checksum"`
	IV        string  `json:"iv"`
	Timestamp float64 `json:"timestamp"`
	FileName  string  `json:"fileName"`
	FileSize  int     `json:"fileSize"`
}

func addLog(entry string, sessionID string) {
	logsLock.Lock()
	defer logsLock.Unlock()

	timestamp := time.Now().Format("2006-01-02 15:04:05")
	logEntry := fmt.Sprintf("[%s] %s\n", timestamp, entry)

	// Make sure the logs directory for this session exists
	logDir := filepath.Join("logs", sessionID)
	if err := os.MkdirAll(logDir, 0755); err != nil {
		fmt.Printf("Error creating log directory: %v\n", err)
		return
	}

	// Path to the write.log file
	logFilePath := filepath.Join(logDir, "write.log")

	// Open file in append mode, create if it doesn’t exist
	f, err := os.OpenFile(logFilePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		fmt.Printf("Error opening log file: %v\n", err)
		return
	}
	defer f.Close()

	// Write log entry
	if _, err := f.WriteString(logEntry); err != nil {
		fmt.Printf("Error writing log: %v\n", err)
	}
}

func main() {
	// Create uploads folder if not exists
	if _, err := os.Stat(uploadDir); os.IsNotExist(err) {
		os.Mkdir(uploadDir, os.ModePerm)
	}

	r := gin.Default()

	// ---- CREATE SESSION ----
	r.POST("/create-session", func(c *gin.Context) {
		rand.Seed(time.Now().UnixNano())
		word := words[rand.Intn(len(words))]

		dirName := filepath.Join(uploadDir, word)
		if err := os.MkdirAll(dirName, 0755); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		addLog(fmt.Sprintf("Created session '%s'", word), word)

		c.JSON(http.StatusOK, gin.H{
			"session_id": word,
		})
	})

	// ---- UPLOAD ----
	r.POST("/upload", func(c *gin.Context) {
		sessionID := c.PostForm("session_id")
		if sessionID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "session_id is required"})
			return
		}

		metadataString := c.PostForm("metadata")
		var metadata FileMetadata
		err := json.Unmarshal([]byte(metadataString), &metadata)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		fileData := c.PostForm("file")
		if fileData == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "file is required"})
			return
		}

		sessionDir := filepath.Join(uploadDir, sessionID)
		if err := os.MkdirAll(sessionDir, 0755); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		fileID := uuid.New().String()
		savePath := filepath.Join(sessionDir, fileID)
		f, err := os.Create(savePath)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer f.Close()

		f.WriteString(fileData)

		metaPath := filepath.Join(sessionDir, "meta.txt")
		mf, err := os.OpenFile(metaPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer mf.Close()
		mf.WriteString(fmt.Sprintf("%s: %s\n", fileID, metadataString))

		addLog(fmt.Sprintf("Session '%s' uploaded file '%s' (%s, %d bytes)", sessionID, metadata.FileName, metadata.Checksum, metadata.FileSize), sessionID)

		c.JSON(http.StatusOK, gin.H{
 			"success":      true,
 			"message":      "File uploaded successfully",
 			"file_id":      fileID,
    		"checksum":     metadata.Checksum,
 			"download_url": fmt.Sprintf("http://localhost:8080/download/%s/%s", sessionID, sessionID),
        })
	})

	// ---- DOWNLOAD ----
	r.GET("/download/:session_id/:filename", func(c *gin.Context) {
		sessionID := c.Param("session_id")
		filename := c.Param("filename")

		filePath := filepath.Join(uploadDir, sessionID, filename)
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			c.JSON(http.StatusNotFound, gin.H{"error": "file not found"})
			return
		}

		addLog(fmt.Sprintf("Session '%s' downloaded file '%s'", sessionID, filename), sessionID)

		c.FileAttachment(filePath, filename)
	})

	r.DELETE("/file/:session_id/:filename", func(c *gin.Context) {
		sessionID := c.Param("session_id")
		filename := c.Param("filename")

		filePath := filepath.Join(uploadDir, sessionID, filename)
		// Check if file exists
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			c.JSON(http.StatusNotFound, gin.H{"error": "file not found"})
			return
		}

		// Delete the file
		if err := os.Remove(filePath); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "could not delete file"})
			return
		}

		metaPath := filepath.Join(uploadDir, sessionID, "meta.txt")

		// 1. Read the current file contents
		metadata, err := os.ReadFile(metaPath)
		if err != nil && !os.IsNotExist(err) {
		    c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		    return
		}

		// 2. Remove lines starting with filename
		cleaned := removeLinesStartingWith(string(metadata), filename)

		// 3. Reopen file for writing (truncate it)
		mf, err := os.OpenFile(metaPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0644)
		if err != nil {
		    c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		    return
		}
		defer mf.Close()

		// 4. Write cleaned content back
		if _, err := mf.WriteString(cleaned); err != nil {
		    c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		    return
		}

		addLog(fmt.Sprintf("File '%s' was deleted from session '%s'", filename, sessionID))
		addLog(fmt.Sprintf("File '%s' was deleted from session '%s'", filename, sessionID), sessionID)

		c.JSON(http.StatusOK, gin.H{"message": "file deleted successfully"})
	})

	// ---- GET ALL META ----
	r.GET("/get-all/:session_id", func(c *gin.Context) {
		sessionID := c.Param("session_id")
		sessionDir := filepath.Join(uploadDir, sessionID)

		metaPath := filepath.Join(sessionDir, "meta.txt")
		content, err := os.ReadFile(metaPath)
		if err != nil {
			if errors.Is(err, os.ErrNotExist) {
		  		c.String(http.StatusOK, "")
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		addLog(fmt.Sprintf("Session '%s' requested metadata listing", sessionID), sessionID)
		c.String(http.StatusOK, string(content))
	})

	// ---- LOGS ENDPOINT ----
	r.GET("/logs/:session_id", func(c *gin.Context) {
		sessionID := c.Param("session_id")

		logsLock.Lock()
		defer logsLock.Unlock()

		logFilePath := filepath.Join("logs", sessionID, "write.log")

		// Read the file
		data, err := os.ReadFile(logFilePath)
		if err != nil {
			if os.IsNotExist(err) {
				c.String(http.StatusOK, "") // no logs yet
			} else {
				c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			}
			return
		}

		// Return the raw content as a string (with \n preserved)
		c.String(http.StatusOK, string(data))
	})

	// ---- START SERVER ----
	fmt.Println("Server running on http://localhost:8000")
	r.Run(":8000")
}



func removeLinesStartingWith(s, prefix string) string {
    lines := strings.Split(s, "\n")
    var result []string
    for _, line := range lines {
        if !strings.HasPrefix(line, prefix) {
            result = append(result, line)
        }
    }
    return strings.Join(result, "\n")
}
