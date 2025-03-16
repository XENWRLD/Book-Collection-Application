import mysql.connector
from flask import Flask, jsonify, request, render_template, redirect, url_for

# Initialize the Flask app
app = Flask(__name__)

# Database configuration
db_config = {
    "host": "localhost",
    "user": "root",
    "password": "asdasqwerk123!",
    "database": "book_collection"
}

# ✅ Test Database Connection
def test_db_connection():
    try:
        conn = mysql.connector.connect(**db_config)
        if conn.is_connected():
            print("Connection Successful!")
        conn.close()
    except mysql.connector.Error as err:
        print(f"Error: {err}")

# Run the test before the app starts
test_db_connection()

# ✅ Database connection function
def get_db_connection():
    conn = mysql.connector.connect(**db_config)
    return conn

# ✅ Home Page
@app.route('/')
def home():
    return render_template('index.html')

# ✅ Register Page
@app.route('/register.html')
def register_page():
    return render_template('register.html')

# ✅ Login Page
@app.route('/login.html')
def login():
    return render_template('login.html')

# ✅ Admin Page - Firebase only, no MySQL query here
@app.route('/admin')
def admin_page():
    return render_template('admin.html')

# ✅ View Books (MySQL)
@app.route('/books/html')
def books_html():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM Book")
    books = cursor.fetchall()
    conn.close()
    return render_template('books.html', books=books)

# ✅ View Authors (MySQL)
@app.route('/authors/html')
def authors_html():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM Author")
    authors = cursor.fetchall()
    conn.close()
    return render_template('authors.html', authors=authors)

# ✅ View Reviews (MySQL)
@app.route('/reviews/html')
def reviews_html():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM Review")
    reviews = cursor.fetchall()
    conn.close()
    return render_template('reviews.html', reviews=reviews)

# ✅ Add Review (MySQL Only)
@app.route('/add_review', methods=['GET', 'POST'])
def add_review_page():
    if request.method == 'POST':
        book_id = request.form['book_id']
        reader_id = request.form['reader_id']
        rating = request.form['rating']
        comment = request.form['comment']

        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(
                "INSERT INTO Review (BookID, ReaderID, Rating, Comment) VALUES (%s, %s, %s, %s)",
                (book_id, reader_id, rating, comment)
            )
            conn.commit()
            return redirect(url_for('reviews_html'))
        except mysql.connector.Error as err:
            conn.rollback()
            return f"Error: {err}"
        finally:
            cursor.close()
            conn.close()
    return render_template('add_review.html')

# ✅ Support Page for Firebase Messages Only
@app.route('/support')
def support_page():
    return render_template('support.html')

# ✅ Register User (MySQL Integration)
@app.route('/register_user', methods=['POST'])
def register_user():
    data = request.json
    uid = data.get('uid')
    name = data.get('name')
    email = data.get('email')

    if not uid or not name or not email:
        return jsonify({"error": "All fields are required"}), 400

    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("INSERT INTO Reader (UID, Name, Email) VALUES (%s, %s, %s)", (uid, name, email))
        conn.commit()
        return jsonify({"message": "User registered successfully in MySQL"}), 201
    except mysql.connector.Error as err:
        conn.rollback()
        return jsonify({"error": str(err)}), 500
    finally:
        cursor.close()
        conn.close()

# ✅ Login User (MySQL Integration)
@app.route('/login_user', methods=['POST'])
def login_user():
    data = request.json
    uid = data.get('uid')

    if not uid:
        return jsonify({"error": "UID is required"}), 400

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SELECT * FROM Reader WHERE UID = %s", (uid,))
        user = cursor.fetchone()
        if user:
            return jsonify({"message": "Login successful!", "user_data": user}), 200
        else:
            return jsonify({"error": "User not found in MySQL"}), 404
    except mysql.connector.Error as err:
        return jsonify({"error": str(err)}), 500
    finally:
        cursor.close()
        conn.close()

# ✅ Get User Data (MySQL Integration)
@app.route('/get_user_data', methods=['GET'])
def get_user_data():
    uid = request.args.get('uid')
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    cursor.execute("SELECT * FROM Reader WHERE UID = %s", (uid,))
    user = cursor.fetchone()
    conn.close()

    if user:
        return jsonify(user), 200
    else:
        return jsonify({"error": "User not found in MySQL"}), 404
    
if __name__ == "__main__":
    app.run(debug=True)
