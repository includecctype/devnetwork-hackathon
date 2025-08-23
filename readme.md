git clone your-repo
cd DEVNETWORK-HACKATHON
docker build -t devnet-hackathon .
docker run -p 3000:3000 -p 8080:8080 -p 8081:8081 -p 8082:8082 devnet-hackathon