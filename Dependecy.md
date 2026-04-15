# Step 1 — install build dependencies
sudo dnf install cargo gdk-pixbuf2-devel pango-devel graphene-devel cairo-gobject-devel cairo-devel gtk4-devel

# Step 2 — install ripdrag via cargo
cargo install ripdrag

# Step 3 — add cargo bin to PATH (if not already)
echo 'export PATH=$PATH:~/.cargo/bin' >> ~/.bashrc
source ~/.bashrc

# Step 4 — verify
ripdrag --version
