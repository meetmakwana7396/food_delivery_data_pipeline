-- Create table for assignment
CREATE TABLE
    IF NOT EXISTS "1100089_orders" (
        order_id SERIAL PRIMARY KEY,
        customer_name VARCHAR(100),
        restaurant_name VARCHAR(100),
        item VARCHAR(100),
        amount NUMERIC(10, 2),
        order_status VARCHAR(20),
        created_at TIMESTAMP NOT NULL DEFAULT NOW ()
    );

-- Initial sample data
INSERT INTO
    "1100089_orders" (
        customer_name,
        restaurant_name,
        item,
        amount,
        order_status
    )
VALUES
    (
        'Alice',
        'Pizza Palace',
        'Margherita Pizza',
        350.00,
        'PLACED'
    ),
    (
        'Bob',
        'Burger Hub',
        'Veg Burger',
        220.00,
        'DELIVERED'
    ),
    (
        'Charlie',
        'Spice House',
        'Paneer Tikka',
        280.00,
        'PREPARING'
    ),
    (
        'David',
        'Noodle Nook',
        'Veg Hakka Noodles',
        210.00,
        'PLACED'
    ),
    (
        'Eva',
        'Curry Corner',
        'Butter Paneer',
        320.00,
        'DELIVERED'
    ),
    (
        'Farhan',
        'Biryani Bhavan',
        'Veg Biryani',
        260.00,
        'CANCELLED'
    ),
    (
        'Gita',
        'Sandwich Stop',
        'Cheese Sandwich',
        150.00,
        'PLACED'
    ),
    (
        'Hari',
        'Wrap World',
        'Paneer Wrap',
        190.00,
        'DELIVERED'
    ),
    (
        'Isha',
        'Dosa Den',
        'Masala Dosa',
        180.00,
        'PREPARING'
    ),
    (
        'Jai',
        'Juice Junction',
        'Mango Shake',
        120.00,
        'DELIVERED'
    );