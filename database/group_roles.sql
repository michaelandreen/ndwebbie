CREATE TABLE roles (
	role VARCHAR(32) UNIQUE NOT NULL
);

CREATE TABLE group_roles (
	gid INTEGER REFERENCES groups(gid),
	role VARCHAR(32) REFERENCES roles(role),
	PRIMARY KEY(gid,role)
);

INSERT INTO roles VALUES('member_menu');
INSERT INTO roles VALUES('hc_menu');
INSERT INTO roles VALUES('bc_menu');
INSERT INTO roles VALUES('dc_menu');
INSERT INTO roles VALUES('intel_menu');
INSERT INTO roles VALUES('attack_menu');
INSERT INTO roles VALUES('no_fleet_update');
INSERT INTO roles VALUES('admin_users');
INSERT INTO roles VALUES('rankings_planet_intel');
INSERT INTO roles VALUES('alliances_resources');

INSERT INTO group_roles (gid,role) VALUES(2,'member_menu');
INSERT INTO group_roles (gid,role) VALUES(2,'attack_menu');
INSERT INTO group_roles (gid,role) VALUES(6,'dc_menu');
INSERT INTO group_roles (gid,role) VALUES(4,'bc_menu');
INSERT INTO group_roles (gid,role) VALUES(5,'intel_menu');
INSERT INTO group_roles (gid,role) VALUES(8,'no_fleet_update');

INSERT INTO group_roles (gid,role) VALUES(1,'dc_menu');
INSERT INTO group_roles (gid,role) VALUES(1,'bc_menu');
INSERT INTO group_roles (gid,role) VALUES(1,'hc_menu');
INSERT INTO group_roles (gid,role) VALUES(1,'intel_menu');
INSERT INTO group_roles (gid,role) VALUES(1,'admin_users');
INSERT INTO group_roles (gid,role) VALUES(1,'rankings_planet_intel');
INSERT INTO group_roles (gid,role) VALUES(1,'alliances_resources');

INSERT INTO group_roles (gid,role) VALUES(3,'dc_menu');
INSERT INTO group_roles (gid,role) VALUES(3,'bc_menu');
INSERT INTO group_roles (gid,role) VALUES(3,'hc_menu');
INSERT INTO group_roles (gid,role) VALUES(3,'intel_menu');
INSERT INTO group_roles (gid,role) VALUES(3,'admin_users');
INSERT INTO group_roles (gid,role) VALUES(3,'rankings_planet_intel');
INSERT INTO group_roles (gid,role) VALUES(3,'alliances_resources');
