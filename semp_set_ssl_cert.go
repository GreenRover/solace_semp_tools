package main

import (
	"fmt"
	scp "github.com/bramvdbogaerde/go-scp"
	"gopkg.in/alecthomas/kingpin.v2"
	"golang.org/x/crypto/ssh"
	"crypto/tls"
	"net/url"
	"net/http"
	"errors"
	"io"
	"io/ioutil"
	"bytes"
	"os"
	"time"
	"strings"
)

// Collection of configs
type config struct {
	uri   			 string
	semp_username    string
	semp_password    string
	scp_username     string
	scp_password     string
	scp_port		 uint
}

// Creates a configuration for a client that authenticates using username and password
func PasswordKey(username string, password string) (ssh.ClientConfig) {
	return ssh.ClientConfig{
		User: username,
		Auth: []ssh.AuthMethod{
			ssh.KeyboardInteractive(func(user, instruction string, questions []string, echos []bool) ([]string, error) {
				// Just send the password back for all questions
				answers := make([]string, len(questions))
				for i, _ := range answers {
					answers[i] = password
				}

				return answers, nil
			}),
		},
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
	}
}

func CopyCertToBroker(scpClient scp.Client, content io.Reader, dst string) error {
	// Connect to the remote server
	err := scpClient.Connect()
	if err != nil {
		return errors.New("Couldn't establish a connection to the remote server: " + err.Error())
	}
	fmt.Println("SCP connection was established")

	// Close client connection after the file has been copied
	defer scpClient.Close()

	contents_bytes, _ := ioutil.ReadAll(content)
	bytes_reader := bytes.NewReader(contents_bytes)
	fmt.Printf("Writing %d bytes\n", len(contents_bytes))
	return scpClient.Copy(bytes_reader, dst, "0655", int64(len(contents_bytes)))
}

// Call http post for the supplied uri and body
func postHTTP(uri string, contentType string, body string, username string, password string) (io.ReadCloser, error) {
	timeout, _ := time.ParseDuration("5s")

	tr := &http.Transport{TLSClientConfig: &tls.Config{InsecureSkipVerify: true}}
	client := http.Client{
		Timeout:       timeout,
		Transport:     tr,
	}

	req, err := http.NewRequest("POST", uri, strings.NewReader(body))
	req.SetBasicAuth(username, password)
	resp, err := client.Do(req)

	if err != nil {
		return nil, err
	}

	if !(resp.StatusCode >= 200 && resp.StatusCode < 300) {
		resp.Body.Close()
		if (resp.StatusCode == 401) {
			return nil, fmt.Errorf("Please check the semp credentials %d", resp.StatusCode)
		}
		return nil, fmt.Errorf("HTTP status %d %s", resp.StatusCode, resp.Status)
	}
	return resp.Body, nil
}


func SempUseCert(certName string, conf config) error {
	type Data struct {
		Reply struct {
			Result string `xml:"code,attr"`
		} `xml:"rpc-reply"`
	}

	command := "<rpc><ssl><server-certificate><filename>" + certName + "</filename></server-certificate></ssl></rpc>"
	body, err := postHTTP(conf.uri + "/SEMP", "application/xml", command, conf.semp_username, conf.semp_password)
	if err != nil {
		return err
	}

	defer body.Close()
	bodyContent, err := ioutil.ReadAll(body)

	if strings.Contains(string(bodyContent), "execute-result code=\"ok\"") {
		return nil
	}

	return errors.New("Semp returned: " + string(bodyContent))
}

func main() {
	var conf config

	kingpin.Flag("api-url", "Base URI of the solace broker.").Default("http://localhost:8080").Envar("API_URL").StringVar(&conf.uri)
	kingpin.Flag("semp-user", "Username for semp api.").Default("admin").Envar("SEMP_USER").StringVar(&conf.semp_username)
	kingpin.Flag("semp-password", "Passwort for semp api.").Default("admin").Envar("SEMP_PASSWORD").StringVar(&conf.semp_password)
	kingpin.Flag("scp-user", "Username for scp.").Default("admin").Envar("FTP_USER").StringVar(&conf.scp_username)
	kingpin.Flag("scp-password", "Passwort for scp.").Default("admin").Envar("FTP_PASSWORD").StringVar(&conf.scp_password)
	kingpin.Flag("scp-port", "Port of scp service.").Default("2222").Envar("API_URL").UintVar(&conf.scp_port)

	kingpin.Parse()

	u, err := url.Parse(conf.uri)
	if err != nil {
		os.Stderr.WriteString("Unable to parse broker url\n")
		os.Stderr.WriteString(err.Error() + "\n")
		os.Exit(1)
	}

	hostname := u.Hostname()
	
	clientConfig := PasswordKey(conf.scp_username, conf.scp_password)

	scpClient := scp.NewClient(hostname + ":" + fmt.Sprint(conf.scp_port), &clientConfig)

	fmt.Println("Connection wia SCP")
	fmt.Println("waiting now for x509 cert + key on STDIN")
	err = CopyCertToBroker(scpClient, os.Stdin, "/certs/broker.crt");
	if err != nil {
		fmt.Print(err.Error)
		os.Stderr.WriteString("Unable to copy cert to broker\n")
		os.Stderr.WriteString(err.Error() + "\n")
		os.Exit(1)
	}
	
	fmt.Println("Activating cert")
	err = SempUseCert("broker.crt", conf);
	if err != nil {
		os.Stderr.WriteString("Unable activate cert, please check if it is an correct pem\n")
		os.Stderr.WriteString(err.Error() + "\n")
		os.Exit(1)
	}

	fmt.Println("Done")
}