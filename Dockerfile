
# Step 1: Use the official Nginx image as the base.
FROM nginx:alpine

# Step 2: Remove the default Nginx welcome page so it doesn't interfere with our files.
RUN rm -rf /usr/share/nginx/html/*

# Step 3: Copy all portfolio files into the Nginx web root directory.
COPY . /usr/share/nginx/html

# Step 4: Tell Docker this container listens on port 80 (standard HTTP port).
EXPOSE 80

# Step 5: Start Nginx when the container runs.
CMD ["nginx", "-g", "daemon off;"]
