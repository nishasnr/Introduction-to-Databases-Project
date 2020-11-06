
-- users table, Users (*UserID, UName)
CREATE TABLE users (
    UserID VARCHAR(30)  PRIMARY KEY,
    UName VARCHAR(30) NOT NULL
);

-- shops table, Shops(*SName)
CREATE TABLE shops (
     SName VARCHAR(30) PRIMARY KEY 
);

-- Employees table, Employees(*EID, EName, Salary)
CREATE TABLE employees(
    EID VARCHAR(30) PRIMARY KEY,
    EName VARCHAR(30) NOT NULL,
    Salary FLOAT NOT NULL CHECK(Salary>0.00)
    
);

-- Products table, Products(*PName, Maker, Category)
CREATE TABLE products(
    PName VARCHAR(80) PRIMARY KEY,
    Maker VARCHAR(30) NOT NULL,
    Category VARCHAR(30) NOT NULL,
);

-- orders table, Orders(*OID, UserID, Shipping_address, Date_time,Shipping_cost)
CREATE TABLE orders(
    OID VARCHAR(30),
    UserID VARCHAR(30),
    Shipping_address VARCHAR(80) NOT NULL,
    Date_time DATETIME NOT NULL,
    Shipping_cost FLOAT NOT NULL CHECK(Shipping_cost>=0.00),
    PRIMARY KEY (OID),
    FOREIGN KEY (UserID) REFERENCES users(UserID) ON UPDATE CASCADE ON DELETE CASCADE
);

-- products_in_shops table, Products_in_shops(*PName, *SName, Price, Qty)
CREATE TABLE products_in_shops (
    PName VARCHAR(80),
    SName VARCHAR(30),
    Price FLOAT NOT NULL CHECK(Price>0.00),
    Qty INT NOT NULL CHECK(Qty>=0),
    PRIMARY KEY (PName, SName),
    FOREIGN KEY (SName) REFERENCES shops(SName) ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (PName) REFERENCES products(PName) ON UPDATE CASCADE ON DELETE CASCADE
    
);

-- products_in_orders table, Products_in_orders(*OID, *SName, *PName,Product_status, Delivery_date, Price, Qty)
CREATE TABLE products_in_orders(
    OID VARCHAR(30),
    SName VARCHAR(30),
    PName VARCHAR(80),
    Product_Status VARCHAR(30) NOT NULL CHECK(Product_Status='processed' OR Product_Status='shipped' OR Product_Status='delivered' OR Product_Status='returned'),
    Delivery_date DATETIME DEFAULT NULL,
    Price FLOAT NOT NULL CHECK(Price>0.00),
    Qty INT NOT NULL  CHECK(Qty>0),
    CHECK((Product_Status='processed' AND Delivery_date IS NULL) OR (Product_Status='shipped' AND Delivery_date IS NULL) OR ( Product_Status<>'shipped' AND Product_Status<>'processed' AND Delivery_date IS NOT NULL)),
    PRIMARY KEY(OID, SName, PName),
    FOREIGN KEY (PName,SName) REFERENCES products_in_shops(PName,SName) ON UPDATE CASCADE ON DELETE CASCADE
);

-- complaints table, Complaints(*CID, EID, Complaint_text, Filled_date_time, Complaint_status, Handled_date_time,UserID)
CREATE TABLE complaints(
    CID VARCHAR(30),
    EID VARCHAR(30),
    Complaint_text VARCHAR(2000) NOT NULL,
    Filled_date_time DATETIME NOT NULL,
    Complaint_status VARCHAR(30) NOT NULL CHECK(Complaint_Status='pending' OR Complaint_Status='being handled' OR Complaint_Status='Addressed') ,
    Handled_date_time DATETIME DEFAULT NULL ,
	UserID VARCHAR(30),
	CHECK(Filled_date_time< Handled_date_time),
	CHECK((Complaint_Status='Addressed' AND Handled_date_time IS NOT NULL) OR (Complaint_Status<>'Addressed' AND Handled_date_time IS NULL)),
    PRIMARY KEY (CID),
    FOREIGN KEY (EID) REFERENCES employees(EID) ON UPDATE CASCADE ON DELETE SET NULL,
    FOREIGN KEY(UserID) REFERENCES Users(UserID) ON UPDATE CASCADE ON DELETE CASCADE
);

-- complaints_on_shops table, Complaints_on_shops(*CID, SName,OID)
CREATE TABLE complaints_on_shops(
    CID VARCHAR(30),
    SName VARCHAR(30),
	OID VARCHAR(30),
    PRIMARY KEY (CID),
	FOREIGN KEY (OID) REFERENCES Orders(OID),
    FOREIGN KEY (CID) REFERENCES complaints(CID) ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (SName) REFERENCES shops(SName) ON UPDATE CASCADE ON DELETE CASCADE
);

-- complaints_on_products table, Complaints_on_products(*CID, PName,Sname,OID)
CREATE TABLE complaints_on_products(
    CID VARCHAR(30),
    PName VARCHAR(80),
    SName VARCHAR(30),
    OID VARCHAR(30),
    PRIMARY KEY (CID),
    FOREIGN KEY (CID) REFERENCES complaints(CID) ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (OID,SName,PName) REFERENCES products_in_orders(OID,SName,PName) ON UPDATE CASCADE ON DELETE CASCADE
);

-- feedback table, Feedback(*OID, *PName, *SName, UserID,Rating, Date-Time, Comment) 
CREATE TABLE feedback(
    OID VARCHAR(30),
    PName VARCHAR(80),
    SName VARCHAR(30),
    Rating INT NOT NULL CHECK(Rating>0 AND Rating<=5),
    Date_time DATETIME NOT NULL,
    Comment VARCHAR(2000),
    PRIMARY KEY (OID, PName, SName),
    FOREIGN KEY (OID,SName,PName) REFERENCES products_in_orders(OID,SName,PName) ON UPDATE CASCADE ON DELETE CASCADE,
);

-- price history table, Price_history(*SName, *PName, *Starting_Date, End_Date, Price)
CREATE TABLE price_history(
    SName VARCHAR(30),
    PName VARCHAR(80),
    Starting_date DATETIME NOT NULL,
    End_date DATETIME DEFAULT NULL ,
    Price FLOAT NOT NULL CHECK(Price>0.00),
    CHECK(Starting_date<End_date),
    PRIMARY KEY (SName, PName, Starting_date),
    FOREIGN KEY (PName,SName) REFERENCES products_in_shops(PName,SName) ON UPDATE CASCADE ON DELETE CASCADE
);


-- trigger to set status of product to 'delivered' after delivery date is set to non null value, not being implemented for now. 
-- choosing to keep on update cascade and on delete cascade for pname,sname key on products_in_orders

/*
GO
CREATE TRIGGER Delivdate
ON Sharkee_website.dbo.products_in_orders
INSTEAD OF UPDATE
NOT FOR REPLICATION
AS
BEGIN
    UPDATE products_in_orders
    SET Delivery_date= CASE
	                          WHEN(d.Product_Status='shipped' and i.Product_Status='delivered')
							        then getdate()
							  else
							         d.Delivery_date
							  end
		 ,Product_Status=CASE
	                          WHEN(d.Product_Status='processed' and i.Product_Status<>'shipped')
							        then 'processed'
							  WHEN(d.Product_Status='shipped' and i.Product_Status<>'delivered')
							        then 'shipped'
							  WHEN(d.Product_Status='delivered' and i.Product_Status<>'returned')
							        then 'delivered'
							  WHEN(d.Product_Status='returned')
							        then 'returned'
							  else
							         i.Product_Status
							  end
    FROM Products_In_Orders o, inserted i, deleted d
    WHERE o.SName=i.SName AND o.PName=i.PName AND o.OID=i.OID AND o.SName=d.SName AND o.PName=d.PName AND o.OID=d.OID;
END*/

-- trigger to set status of complaint to 'resolved' after handled_date is set to non null value 
/*
GO
CREATE Trigger ComplaintHandledTrig
ON Sharkee_website.dbo.Complaints
INSTEAD OF UPDATE
NOT FOR REPLICATION
AS
BEGIN
       UPDATE Complaints 
       set Handled_date_time= CASE
	                          WHEN(d.Complaint_Status='being handled' and i.Complaint_Status='addressed')
							        then getdate()
							  else
							         d.Handled_date_time
							  end
		 ,Complaint_Status=CASE
	                          WHEN(d.Complaint_Status='pending' and i.Complaint_Status<>'being handled')
							        then 'pending'
							  WHEN(d.Complaint_Status='being handled' and i.Complaint_Status<>'addressed')
							        then 'being handled'
							  WHEN(d.Complaint_Status='addressed')
							        then 'addressed'
							  else
							         i.Complaint_Status
							  end
	   FROM	Complaints o,inserted i, deleted d
       WHERE o.CID=i.CID AND o.CID=d.CID;
END
*/
-- trigger to update price_history once price in products_in_shops is changed. First the end date of the latest entry 
--(which would be null) is set to current time and then new row is inserted with start_time as current time and end_date as null

GO 
CREATE TRIGGER UpdatePriceHistwithProdinShopsTrig
ON Sharkee_website.dbo.Products_in_shops
AFTER UPDATE
NOT FOR REPLICATION
AS
BEGIN
       UPDATE Sharkee_website.dbo.price_history
       SET End_date= CASE
	                    when(i.Price<>d.Price AND p.End_date IS NULL)
	                       then getdate()
						end
	   FROM	price_history p,inserted i, deleted d
       WHERE p.SName=i.SName AND p.PName=i.PName AND p.SName=d.SName AND p.PName=d.PName;
       INSERT INTO Sharkee_website.dbo.price_history
	   SELECT
	        i.SName,
			i.PName,
			GETDATE(),
			NULL,
			i.Price
	   FROM inserted i,price_history p,deleted d
	   WHERE p.SName=i.SName AND p.PName=i.PName AND p.SName=d.SName AND p.PName=d.PName AND i.Price<>d.Price;
	 
       
END

--trigger when products in orders gets a new entry. maps back to price_history in whose interval order date_time of product
-- is present and updates the product's price to relevant price
GO
CREATE TRIGGER GetPriceTrig
ON Sharkee_website.dbo.Products_in_orders
AFTER INSERT
NOT FOR REPLICATION
AS
BEGIN 
       UPDATE Sharkee_website.dbo.Products_in_orders
	   SET Price=p.Price
	   FROM price_history p,inserted i,orders o, products_in_orders pr
	   WHERE i.OID=pr.OID and pr.SName=i.SName and pr.PName=i.PName and i.OID=o.OID and p.SName=i.SName and p.PName=i.PName and o.Date_time>=p.Starting_date and (o.Date_time<p.End_date OR p.End_date is NULL);
END