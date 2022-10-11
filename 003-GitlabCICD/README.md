



/etc/gitlab/initial_root_password

docker exec <gitlab runner container> -it bash
curl --request POST -k "https://gitlab.chance20221011.com/api/v4/runners" \
     --form "token=GR1348941Pjv5QzazEy4-32MPsArC" --form "description=test-20221010" \
     --form "tag_list=test"

# gitlab
cd /etc/gitlab/ssl
mkdir backup
mv * backup
openssl genrsa -out ca.key 2048
openssl req -new -x509 -days 365 -key ca.key -subj "/C=CN/ST=GD/L=SZ/O=Acme, Inc./CN=Acme Root CA" -out ca.crt
openssl req -newkey rsa:2048 -nodes -keyout gitlab.chance20221011.com.key -subj "/C=CN/ST=GD/L=SZ/O=Acme, Inc./CN=*.chance20221011.com" -out gitlab.chance20221011.com.csr
openssl x509 -req -extfile <(printf "subjectAltName=DNS:chance20221011.com,DNS:gitlab.chance20221011.com") -days 365 -in gitlab.chance20221011.com.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out gitlab.chance20221011.com.crt


gitlab-cli reconfigure
gitlab-cli restart


# gitlab runner
docker exec <gitlab container> cat /etc/gitlab/ssl/gitlab.chance20221011.com.crt

docker exec <gitlab runner container> echo <above crt> > /usr/local/share/ca-certificates/gitlab.chance20221011.com.crt
docker exec <gitlab runner container> update-ca-certificates
# gitlab-runner register 
Runtime platform                                    arch=amd64 os=linux pid=4667 revision=43b2dc3d version=15.4.0
Running in system-mode.                            
                                                   
Enter the GitLab instance URL (for example, https://gitlab.com/):
https://gitlab.chance20221011.com/
Enter the registration token:
GR1348941Pjv5QzazEy4-32MPsArC
Enter a description for the runner:
[bad518d25b44]: tests
Enter tags for the runner (comma-separated):
test
Enter optional maintenance note for the runner:
test
Registering runner... succeeded                     runner=GR1348941Pjv5Qzaz
Enter an executor: ssh, docker+machine, docker-ssh, docker, parallels, shell, virtualbox, docker-ssh+machine, kubernetes, custom:
shell
Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded!
 
Configuration (with the authentication token) was saved in "/etc/gitlab-runner/config.toml" 
root@bad518d25b44:/usr/local/share/ca-certificates# cat /etc/gitlab-runner/config.toml 


Issue 1:
Letencrypt DNS issue
Soluton:
Chnage hostname to .com and wait for 1 hour

Reference
https://docs.gitlab.com/ee/install/docker.html#install-gitlab-using-docker-compose
