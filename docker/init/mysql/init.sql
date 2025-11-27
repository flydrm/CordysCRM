-- ============================================================================
-- Cordys CRM - MySQL 初始化脚本
-- ============================================================================

-- 创建数据库（如果不存在）
CREATE DATABASE IF NOT EXISTS `cordys-crm` 
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

-- 切换到数据库
USE `cordys-crm`;

-- 授权应用用户
GRANT ALL PRIVILEGES ON `cordys-crm`.* TO 'cordys'@'%';
FLUSH PRIVILEGES;

-- 显示初始化完成信息
SELECT 'Cordys CRM MySQL 初始化完成' AS message;

