docker build --build-arg VERSION=1.5.0  -t llm-load:1.5.0

docker run -it --rm -p 3001:3001 -v ./data:/app/data -e AUTH_KEY=sk-123456 llm-load:1.5.0
