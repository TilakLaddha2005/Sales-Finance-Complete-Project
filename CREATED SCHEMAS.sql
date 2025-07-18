-- CREATING SCHEMAS_ 

CREATE TABLE customers(
customer_id INT PRIMARY KEY,
customer_name VARCHAR(255),
customer_email VARCHAR(255),
customer_state VARCHAR(100),
customer_since DATE
);

CREATE TABLE products(
product_id INT PRIMARY KEY,
product_name VARCHAR(255),
category VARCHAR(150),
price FLOAT
);

CREATE TABLE orders(
order_id INT PRIMARY KEY,
customer_id INT,
order_date DATE,
order_status VARCHAR(150),
CONSTRAINT orders_customers_fk FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items(
order_item_id INT PRIMARY KEY,
order_id INT,
product_id INT,
quantity INT,
price FLOAT,
total_price FLOAT,
CONSTRAINT order_items_orders_fk FOREIGN KEY (order_id) REFERENCES orders(order_id),
CONSTRAINT order_items_products_fk FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE payments(
payment_id INT PRIMARY KEY,
order_id INT,
payment_date DATE,
payment_amount FLOAT,
payment_method VARCHAR(155),
CONSTRAINT payments_orders_fk FOREIGN KEY (order_id) REFERENCES orders(order_id)
);