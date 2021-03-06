INSERT INTO wiki_namespaces VALUES ('');
INSERT INTO wiki_namespaces VALUES ('Members');
INSERT INTO wiki_namespaces VALUES ('HC');
INSERT INTO wiki_namespaces VALUES ('Tech');
INSERT INTO wiki_namespaces VALUES ('Info');

INSERT INTO wiki_pages (name,namespace) VALUES('Main','Info');
INSERT INTO wiki_page_revisions (wpid,text,comment,uid) VALUES(1,'Welcome to the main page!', 'First revision', 1);

INSERT INTO wiki_namespace_access (namespace,gid,edit,post,moderate) VALUES ('',-1,FALSE,FALSE,FALSE);
INSERT INTO wiki_namespace_access (namespace,gid,edit,post,moderate) VALUES ('',11,TRUE,TRUE,FALSE);
INSERT INTO wiki_namespace_access (namespace,gid,edit,post,moderate) VALUES ('',1,TRUE,TRUE,TRUE);
INSERT INTO wiki_namespace_access (namespace,gid,edit,post,moderate) VALUES ('',3,TRUE,TRUE,TRUE);

INSERT INTO wiki_namespace_access (namespace,gid,edit,post,moderate) VALUES ('Info',-1,FALSE,FALSE,FALSE);
INSERT INTO wiki_namespace_access (namespace,gid,edit,post,moderate) VALUES ('Info',1,TRUE,TRUE,TRUE);
INSERT INTO wiki_namespace_access (namespace,gid,edit,post,moderate) VALUES ('Info',3,TRUE,TRUE,TRUE);

INSERT INTO wiki_namespace_access (namespace,gid,edit,post,moderate) VALUES ('Members',2,TRUE,TRUE,FALSE);
INSERT INTO wiki_namespace_access (namespace,gid,edit,post,moderate) VALUES ('Members',1,TRUE,TRUE,TRUE);
INSERT INTO wiki_namespace_access (namespace,gid,edit,post,moderate) VALUES ('Members',3,TRUE,TRUE,TRUE);

INSERT INTO wiki_namespace_access (namespace,gid,edit,post,moderate) VALUES ('HC',1,TRUE,TRUE,TRUE);
INSERT INTO wiki_namespace_access (namespace,gid,edit,post,moderate) VALUES ('HC',3,TRUE,TRUE,TRUE);

INSERT INTO wiki_namespace_access (namespace,gid,edit,post,moderate) VALUES ('Tech',-1,FALSE,FALSE,FALSE);
INSERT INTO wiki_namespace_access (namespace,gid,edit,post,moderate) VALUES ('Tech',2,TRUE,TRUE,FALSE);
INSERT INTO wiki_namespace_access (namespace,gid,edit,post,moderate) VALUES ('Tech',1,TRUE,TRUE,TRUE);
INSERT INTO wiki_namespace_access (namespace,gid,edit,post,moderate) VALUES ('Tech',3,TRUE,TRUE,TRUE);

