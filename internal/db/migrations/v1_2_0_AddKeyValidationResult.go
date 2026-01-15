package db

import (
	"gpt-load/internal/models"

	"gorm.io/gorm"
)

// V1_2_0_AddKeyValidationResult adds last_validation_status and last_validation_response columns to api_keys table
func V1_2_0_AddKeyValidationResult(db *gorm.DB) error {
	return db.AutoMigrate(&models.APIKey{})
}
