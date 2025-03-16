DROP TABLE IF EXISTS BooksReadLog;
DROP TABLE IF EXISTS BooksRead;
DROP TABLE IF EXISTS Review;
DROP TABLE IF EXISTS Book;
DROP TABLE IF EXISTS Reader;
DROP TABLE IF EXISTS Author;
DROP TABLE IF EXISTS ReviewLog;
DROP TABLE IF EXISTS ReaderLog;
DROP TABLE IF EXISTS BookLog;
DROP TABLE IF EXISTS AuthorLog;


DROP PROCEDURE IF EXISTS AddReview;
DROP PROCEDURE IF EXISTS UpdateAverageRating;
DROP PROCEDURE IF EXISTS ReaderBookReport;
DROP PROCEDURE IF EXISTS AddBook;
DROP PROCEDURE IF EXISTS DeleteReader;
DROP PROCEDURE IF EXISTS TopRatedAuthors;
DROP PROCEDURE IF EXISTS MostActiveReaders;
DROP PROCEDURE IF EXISTS BooksByGenre;
DROP PROCEDURE IF EXISTS BooksWithoutReviews;
DROP PROCEDURE IF EXISTS LeastRatedBooks;
DROP PROCEDURE IF EXISTS InactiveReaders;

-- Create Author table
CREATE TABLE Author (
    AuthorID INT PRIMARY KEY,
    Name CHAR(100) NOT NULL,
    Country CHAR(50)
);

-- Create Book table with average_rating
CREATE TABLE Book (
    BookID INT PRIMARY KEY,
    Title CHAR(150) NOT NULL,
    YearPublished INT CHECK (YearPublished >= 0),
    Genre CHAR(50),
    AuthorID INT NOT NULL,
    average_rating DECIMAL(3,2) DEFAULT 0,
    CONSTRAINT fk_author FOREIGN KEY (AuthorID) REFERENCES Author(AuthorID),
    CONSTRAINT unique_title_author UNIQUE (Title, AuthorID)
);

-- Create Reader table
CREATE TABLE Reader (
    ReaderID INT AUTO_INCREMENT PRIMARY KEY,
    Name CHAR(100) NOT NULL,
    Email CHAR(100) UNIQUE NOT NULL
);

-- Create Review table
CREATE TABLE Review (
    ReviewID INT AUTO_INCREMENT PRIMARY KEY, -- Add AUTO_INCREMENT
    BookID INT NOT NULL,
    ReaderID INT NOT NULL,
    Rating INT CHECK (Rating BETWEEN 1 AND 5),
    Comment TEXT,
    Timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_book FOREIGN KEY (BookID) REFERENCES Book(BookID) ON DELETE CASCADE,
    CONSTRAINT fk_reader FOREIGN KEY (ReaderID) REFERENCES Reader(ReaderID) ON DELETE CASCADE
);


-- Create BooksRead table
CREATE TABLE BooksRead (
    ReaderID INT NOT NULL,
    BookID INT NOT NULL,
    DateRead DATE NOT NULL,
	Timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (ReaderID, BookID),
    FOREIGN KEY (ReaderID) REFERENCES Reader(ReaderID) ON DELETE CASCADE,
    FOREIGN KEY (BookID) REFERENCES Book(BookID) ON DELETE CASCADE
);

-- Create ReviewLog table
CREATE TABLE ReviewLog (
    LogID INT AUTO_INCREMENT PRIMARY KEY,
    ReviewID INT,
    BookID INT,
    ReaderID INT,
    Action VARCHAR(50),
    Timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE BooksReadLog (
    LogID INT AUTO_INCREMENT PRIMARY KEY,
    ReaderID INT NOT NULL,
    BookID INT NOT NULL,
    Action VARCHAR(50), -- 'Book Read' or 'Book Unread'
    Timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ReaderID) REFERENCES Reader(ReaderID) ON DELETE CASCADE,
    FOREIGN KEY (BookID) REFERENCES Book(BookID) ON DELETE CASCADE
);

CREATE TABLE ReaderLog (
    LogID INT AUTO_INCREMENT PRIMARY KEY,
    ReaderID INT,
    Action VARCHAR(50),
    Timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE BookLog (
    LogID INT AUTO_INCREMENT PRIMARY KEY,
    BookID INT,
    Action VARCHAR(50),
    Timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE AuthorLog (
    LogID INT AUTO_INCREMENT PRIMARY KEY,
    AuthorID INT,
    Action VARCHAR(50),
    Timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


DELIMITER //

CREATE TRIGGER after_review_insert
AFTER INSERT ON Review
FOR EACH ROW
BEGIN
    INSERT INTO ReviewLog (ReviewID, BookID, ReaderID, Action)
    VALUES (NEW.ReviewID, NEW.BookID, NEW.ReaderID, 'Review Added');

    UPDATE Book
    SET average_rating = (
        SELECT AVG(Rating)
        FROM Review
        WHERE BookID = NEW.BookID
    )
    WHERE BookID = NEW.BookID;
END //

DELIMITER ;


DELIMITER //

CREATE TRIGGER after_review_delete
AFTER DELETE ON Review
FOR EACH ROW
BEGIN
	    -- Log the deletion in the ReviewLog table
    INSERT INTO ReviewLog (ReviewID, BookID, ReaderID, Action)
    VALUES (OLD.ReviewID, OLD.BookID, OLD.ReaderID, 'Review Deleted');
    
    UPDATE Book
    SET average_rating = (
        SELECT IFNULL(AVG(Rating), 0.00)
        FROM Review
        WHERE BookID = OLD.BookID
    )
    WHERE BookID = OLD.BookID;
END //

DELIMITER ;


DELIMITER //

CREATE TRIGGER after_booksread_insert
AFTER INSERT ON BooksRead
FOR EACH ROW
BEGIN
    INSERT INTO BooksReadLog (ReaderID, BookID, Action)
    VALUES (NEW.ReaderID, NEW.BookID, 'Book Read');
END //

DELIMITER ;


DELIMITER //

CREATE TRIGGER after_review_update
AFTER UPDATE ON Review
FOR EACH ROW
BEGIN
    UPDATE Book
    SET average_rating = (
        SELECT AVG(Rating)
        FROM Review
        WHERE BookID = NEW.BookID
    )
    WHERE BookID = NEW.BookID;
END //

DELIMITER ;



DELIMITER //

CREATE TRIGGER after_booksread_delete
AFTER DELETE ON BooksRead
FOR EACH ROW
BEGIN
    INSERT INTO BooksReadLog (ReaderID, BookID, Action)
    VALUES (OLD.ReaderID, OLD.BookID, 'Book Unread');
END //

DELIMITER ;


DELIMITER //

CREATE TRIGGER after_reader_delete
AFTER DELETE ON Reader
FOR EACH ROW
BEGIN
    INSERT INTO ReaderLog (ReaderID, Action)
    VALUES (OLD.ReaderID, 'Reader Deleted');
END //

DELIMITER ;


DELIMITER //

CREATE TRIGGER after_book_delete
AFTER DELETE ON Book
FOR EACH ROW
BEGIN
    INSERT INTO BookLog (BookID, Action)
    VALUES (OLD.BookID, 'Book Deleted');
END //

DELIMITER ;


DELIMITER //

CREATE TRIGGER after_author_delete
AFTER DELETE ON Author
FOR EACH ROW
BEGIN
    INSERT INTO AuthorLog (AuthorID, Action)
    VALUES (OLD.AuthorID, 'Author Deleted');
END //

DELIMITER ;

DELIMITER //

CREATE TRIGGER after_author_insert
AFTER INSERT ON Author
FOR EACH ROW
BEGIN
    INSERT INTO AuthorLog (AuthorID, Action)
    VALUES (NEW.AuthorID, 'Author Added');
END //

DELIMITER ;

DELIMITER //

CREATE TRIGGER after_book_insert
AFTER INSERT ON Book
FOR EACH ROW
BEGIN
    INSERT INTO BookLog (BookID, Action)
    VALUES (NEW.BookID, 'Book Added');
END //

DELIMITER ;

DELIMITER //

CREATE TRIGGER after_reader_insert
AFTER INSERT ON Reader
FOR EACH ROW
BEGIN
    INSERT INTO ReaderLog (ReaderID, Action)
    VALUES (NEW.ReaderID, 'Reader Added');
END //

DELIMITER ;


DELIMITER $$

CREATE PROCEDURE AddReview (
    IN p_BookID INT,
    IN p_ReaderID INT,
    IN p_Rating INT,
    IN p_Comment TEXT
)
BEGIN
    -- Validate Rating Range
    IF p_Rating < 1 OR p_Rating > 5 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Rating must be between 1 and 5.';
    END IF;

    -- Ensure BookID and ReaderID exist
    IF NOT EXISTS (SELECT 1 FROM Book WHERE BookID = p_BookID) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'BookID does not exist.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Reader WHERE ReaderID = p_ReaderID) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ReaderID does not exist.';
    END IF;

    -- Insert Review
    INSERT INTO Review (BookID, ReaderID, Rating, Comment)
    VALUES (p_BookID, p_ReaderID, p_Rating, p_Comment);
END $$

DELIMITER ;


DELIMITER $$

CREATE PROCEDURE UpdateAverageRating (
    IN p_BookID INT
)
BEGIN
    -- Recalculate average rating for the specified book
    UPDATE Book
    SET average_rating = (
        SELECT AVG(Rating)
        FROM Review
        WHERE BookID = p_BookID
    )
    WHERE BookID = p_BookID;
END $$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE ReaderBookReport (
    IN p_ReaderID INT
)
BEGIN
    SELECT
        B.Title AS BookTitle,
        A.Name AS AuthorName,
        B.Genre,
        R.Rating,
        R.Comment
    FROM
        Review R
        INNER JOIN Book B ON R.BookID = B.BookID
        INNER JOIN Author A ON B.AuthorID = A.AuthorID
    WHERE
        R.ReaderID = p_ReaderID;
END $$

DELIMITER ;


DELIMITER $$

CREATE PROCEDURE AddBook (
    IN p_BookID INT,
    IN p_Title VARCHAR(255),
    IN p_YearPublished YEAR,
    IN p_Genre VARCHAR(100),
    IN p_AuthorID INT
)
BEGIN
    -- Ensure AuthorID exists
    IF NOT EXISTS (SELECT 1 FROM Author WHERE AuthorID = p_AuthorID) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'AuthorID does not exist.';
    END IF;

    -- Insert Book
    INSERT INTO Book (BookID, Title, YearPublished, Genre, AuthorID, average_rating)
    VALUES (p_BookID, p_Title, p_YearPublished, p_Genre, p_AuthorID, 0.00);
END $$

DELIMITER ;


DELIMITER $$

CREATE PROCEDURE DeleteReader (
    IN p_ReaderID INT
)
BEGIN
    -- Delete related reviews
    DELETE FROM Review WHERE ReaderID = p_ReaderID;

    -- Delete related logs
    DELETE FROM BooksReadLog WHERE ReaderID = p_ReaderID;

    -- Delete reader
    DELETE FROM Reader WHERE ReaderID = p_ReaderID;
END $$

DELIMITER ;


DELIMITER $$

CREATE PROCEDURE TopRatedAuthors ()
BEGIN
    SELECT
        A.Name AS AuthorName,
        AVG(B.average_rating) AS AvgRating
    FROM
        Author A
        INNER JOIN Book B ON A.AuthorID = B.AuthorID
    GROUP BY
        A.AuthorID
    ORDER BY
        AvgRating DESC
    LIMIT 10;
END $$

DELIMITER ;


DELIMITER $$

CREATE PROCEDURE MostActiveReaders ()
BEGIN
    SELECT
        R.Name AS ReaderName,
        COUNT(ReviewID) AS TotalReviews,
        COUNT(DISTINCT B.BookID) AS TotalBooksRead
    FROM
        Reader R
        LEFT JOIN Review Rev ON R.ReaderID = Rev.ReaderID
        LEFT JOIN BooksReadLog B ON R.ReaderID = B.ReaderID
    GROUP BY
        R.ReaderID
    ORDER BY
        TotalReviews DESC, TotalBooksRead DESC
    LIMIT 10;
END $$

DELIMITER ;


DELIMITER $$

CREATE PROCEDURE BooksByGenre (
    IN p_Genre VARCHAR(100)
)
BEGIN
    SELECT
        Title,
        YearPublished,
        average_rating
    FROM
        Book
    WHERE
        Genre = p_Genre
    ORDER BY
        average_rating DESC;
END $$

DELIMITER ;


DELIMITER $$

CREATE PROCEDURE BooksWithoutReviews ()
BEGIN
    SELECT 
        B.BookID,
        B.Title AS BookTitle,
        A.Name AS AuthorName,
        B.Genre
    FROM 
        Book B
        LEFT JOIN Review R ON B.BookID = R.BookID
    INNER JOIN Author A ON B.AuthorID = A.AuthorID
    WHERE 
        R.BookID IS NULL;
END $$

DELIMITER ;


DELIMITER $$

CREATE PROCEDURE LeastRatedBooks ()
BEGIN
    SELECT 
        BookID,
        Title,
        average_rating
    FROM 
        Book
    WHERE 
        average_rating > 0
    ORDER BY 
        average_rating ASC
    LIMIT 10;
END $$

DELIMITER ;



DELIMITER $$

CREATE PROCEDURE InactiveReaders (IN months_ago INT)
BEGIN
    SELECT 
        R.ReaderID,
        R.Name AS ReaderName,
        -- Use NULL if there's no activity; only use the latest activity date
        MAX(GREATEST(
            COALESCE((SELECT MAX(Timestamp) FROM Review WHERE ReaderID = R.ReaderID), NULL),
            COALESCE((SELECT MAX(Timestamp) FROM BooksReadLog WHERE ReaderID = R.ReaderID), NULL)
        )) AS LastActivity
    FROM 
        Reader R
    GROUP BY 
        R.ReaderID, R.Name
    HAVING 
        -- This will show only those with no recent activity or no activity at all
        LastActivity < DATE_SUB(CURDATE(), INTERVAL months_ago MONTH) OR LastActivity IS NULL;
END $$

DELIMITER ;



INSERT INTO Author VALUES (1, 'George Orwell', 'United Kingdom');
INSERT INTO Author VALUES (2, 'Harper Lee', 'United States');
INSERT INTO Author VALUES (3, 'J.K. Rowling', 'United Kingdom');
INSERT INTO Author VALUES (4, 'F. Scott Fitzgerald', 'United States');
INSERT INTO Author VALUES (5, 'J.R.R. Tolkien', 'United Kingdom');
INSERT INTO Author VALUES (6, 'Ernest Hemingway', 'United States');
INSERT INTO Author VALUES (7, 'Jane Austen', 'United Kingdom');
INSERT INTO Author VALUES (8, 'Agatha Christie', 'United Kingdom');
INSERT INTO Author VALUES (9, 'Mark Twain', 'United States');
INSERT INTO Author VALUES (10, 'Leo Tolstoy', 'Russia');


INSERT INTO Book VALUES (1, '1984', 1949, 'Dystopian', 1, 3.00);
INSERT INTO Book VALUES (2, 'Animal Farm', 1945, 'Political Satire', 1, 2.50);
INSERT INTO Book VALUES (3, 'To Kill a Mockingbird', 1960, 'Classic Fiction', 2, 1.20);
INSERT INTO Book VALUES (4, 'The Great Gatsby', 1925, 'Novel', 4, 0.00);
INSERT INTO Book VALUES (5, 'Harry Potter and the Philosopher\'s Stone', 1997, 'Fantasy', 3, 4.80);
INSERT INTO Book VALUES (6, 'The Hobbit', 1937, 'Fantasy', 5, 0.00);
INSERT INTO Book VALUES (7, 'Pride and Prejudice', 1813, 'Romance', 7, 1.00);
INSERT INTO Book VALUES (8, 'Murder on the Orient Express', 1934, 'Mystery', 8, 3.06);
INSERT INTO Book VALUES (9, 'The Adventures of Tom Sawyer', 1876, 'Adventure', 9, 2.55);
INSERT INTO Book VALUES (10, 'War and Peace', 1869, 'Historical Fiction', 10, 1.20);

INSERT INTO Reader (Name, Email) VALUES ('Alice Johnson', 'alice@example.com');
INSERT INTO Reader (Name, Email) VALUES ('Bob Smith', 'bob@example.com');
INSERT INTO Reader (Name, Email) VALUES ('Charlie Brown', 'charlie@example.com');
INSERT INTO Reader (Name, Email) VALUES ('Diana Prince', 'diana@example.com');
INSERT INTO Reader (Name, Email) VALUES ('Edward Norton', 'edward@example.com');
INSERT INTO Reader (Name, Email) VALUES ('Fiona Gallagher', 'fiona@example.com');
INSERT INTO Reader (Name, Email) VALUES ('George Clooney', 'george@example.com');
INSERT INTO Reader (Name, Email) VALUES ('Hannah Abbott', 'hannah@example.com');
INSERT INTO Reader (Name, Email) VALUES ('Ian McKellen', 'ian@example.com');
INSERT INTO Reader (Name, Email) VALUES ('Jane Goodall', 'jane@example.com');


INSERT INTO Review (BookID, ReaderID, Rating, Comment)
VALUES (1, 1, 5, 'A masterpiece.');

INSERT INTO Review (BookID, ReaderID, Rating, Comment)
VALUES (2, 2, 4, 'Very thought-provoking.');

INSERT INTO Review (BookID, ReaderID, Rating, Comment)
VALUES (3, 3, 5, 'A timeless classic.');

INSERT INTO Review (BookID, ReaderID, Rating, Comment)
VALUES (5, 4, 5, 'An amazing fantasy journey.');

INSERT INTO Review (BookID, ReaderID, Rating, Comment)
VALUES (6, 5, 4, 'A delightful read.');

INSERT INTO Review (BookID, ReaderID, Rating, Comment)
VALUES (7, 6, 5, 'A beautiful romance.');

INSERT INTO Review (BookID, ReaderID, Rating, Comment)
VALUES (8, 7, 4, 'Captivating mystery.');

INSERT INTO Review (BookID, ReaderID, Rating, Comment)
VALUES (9, 8, 5, 'Great adventure story.');

INSERT INTO Review (BookID, ReaderID, Rating, Comment)
VALUES (10, 9, 5, 'A must-read.');

INSERT INTO Review (BookID, ReaderID, Rating, Comment)
VALUES (4, 10, 4, 'An interesting novel.');


INSERT INTO BooksRead (ReaderID, BookID, DateRead)
VALUES (1, 1, '2024-10-17');
INSERT INTO BooksRead (ReaderID, BookID, DateRead)
VALUES (2, 3, '2024-09-12');
INSERT INTO BooksRead (ReaderID, BookID, DateRead)
VALUES (3, 5, '2024-08-05');
INSERT INTO BooksRead (ReaderID, BookID, DateRead)
VALUES (4, 7, '2024-07-14');
INSERT INTO BooksRead (ReaderID, BookID, DateRead)
VALUES (5, 2, '2024-06-22');
INSERT INTO BooksRead (ReaderID, BookID, DateRead)
VALUES (6, 4, '2024-05-10');
INSERT INTO BooksRead (ReaderID, BookID, DateRead)
VALUES (7, 6, '2024-04-03');
INSERT INTO BooksRead (ReaderID, BookID, DateRead)
VALUES (8, 8, '2024-03-29');
INSERT INTO BooksRead (ReaderID, BookID, DateRead)
VALUES (9, 9, '2024-02-17');
INSERT INTO BooksRead (ReaderID, BookID, DateRead)
VALUES (10, 10, '2024-01-25');

-- Insert non-active readers (without reviews or books read)
INSERT INTO Reader (ReaderID, Name, Email)
VALUES (11, 'Non-Active Reader 1', 'inactive1@example.com');

INSERT INTO Reader (ReaderID, Name, Email)
VALUES (12, 'Non-Active Reader 2', 'inactive2@example.com');


-- Add a new review
INSERT INTO Review (ReviewID, BookID, ReaderID, Rating, Comment)
VALUES (11, 3, 1, 5, 'A new review to test trigger');


/*
-- Check if the ReviewLog has the correct entry
SELECT * FROM ReviewLog;

-- Update an existing review
UPDATE Review
SET Rating = 4, Comment = 'A slightly updated review.'
WHERE ReviewID = 1;

-- Check the Book table for updated average rating
SELECT * FROM Book WHERE BookID = 1;

-- Delete a review
DELETE FROM Review WHERE ReviewID = 1;

-- Check if the ReviewLog has the correct entry
SELECT * FROM ReviewLog;

-- Add a new book read entry
INSERT INTO BooksRead (ReaderID, BookID, DateRead)
VALUES (1, 2, '2024-12-01');

-- Check if BooksReadLog has the correct entry
SELECT * FROM BooksReadLog;

-- Delete a book read entry
DELETE FROM BooksRead WHERE ReaderID = 1 AND BookID = 2;

-- Check if BooksReadLog has the correct entry
SELECT * FROM BooksReadLog;


-- Delete a reader
DELETE FROM Reader WHERE ReaderID = 11;

-- Check if ReaderLog has the correct entry
SELECT * FROM ReaderLog;
*/

/*
-- Call the stored procedure for top-rated authors
CALL TopRatedAuthors();

-- Call the stored procedure for most active readers
CALL MostActiveReaders();

-- Call the stored procedure for books by genre
CALL BooksByGenre('Dystopian');

CALL BooksByGenre('Classic Fiction');

-- Call the stored procedure for inactive readers (inactive for 6 months)
CALL InactiveReaders(6);
*/

-- Show foreign key relationships in the database
SELECT 
    TABLE_NAME,
    COLUMN_NAME,
    CONSTRAINT_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM 
    INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE 
    TABLE_SCHEMA = 'book_collection';

/*
-- View data in the Author table
SELECT * FROM Author;
-- View data in the Book table
SELECT * FROM Book;
-- View data in the Reader table
SELECT * FROM Reader;
-- View data in the Review table
SELECT * FROM Review;
-- View data in the BooksRead table
SELECT * FROM BooksRead;
-- View data in the ReviewLog table
SELECT * FROM ReviewLog;
-- View data in the BooksReadLog table
SELECT * FROM BooksReadLog;
-- View data in the ReaderLog table
SELECT * FROM ReaderLog;
-- View data in the BookLog table
SELECT * FROM BookLog;
-- View data in the AuthorLog table
SELECT * FROM AuthorLog;
*/

SHOW PROCEDURE STATUS WHERE Db = 'book_collection';
INSERT INTO Review (BookID, ReaderID, Rating, Comment) 
VALUES (1, 1, 5, 'Great book!');


SELECT * FROM Review;
SHOW TRIGGERS;
SHOW DATABASES;
SELECT * FROM Review ORDER BY ReviewID DESC LIMIT 1;
SHOW WARNINGS;
DESCRIBE Review;
SHOW GRANTS FOR 'root'@'localhost';


SELECT VERSION();


CALL AddReview(1, 1, 5, 'Great book!');
