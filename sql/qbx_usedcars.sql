CREATE TABLE IF NOT EXISTS qbx_usedcar_listings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    seller_cid VARCHAR(64) NOT NULL,
    seller_name VARCHAR(64) NOT NULL,
    plate VARCHAR(16) NOT NULL,
    vehicle_props LONGTEXT NOT NULL,
    price INT NOT NULL,
    status ENUM('active','sold','cancelled') DEFAULT 'active',
    buyer_cid VARCHAR(64) DEFAULT NULL,
    pos_x DOUBLE NOT NULL DEFAULT 0,
    pos_y DOUBLE NOT NULL DEFAULT 0,
    pos_z DOUBLE NOT NULL DEFAULT 0,
    heading DOUBLE NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_qbx_usedcars_status ON qbx_usedcar_listings (status);
CREATE INDEX idx_qbx_usedcars_pos ON qbx_usedcar_listings (pos_x, pos_y);
CREATE INDEX idx_qbx_usedcars_seller ON qbx_usedcar_listings (seller_cid);

