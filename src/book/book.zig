const std = @import("std");
const Map = @import("./map.zig").Map;

const Side = enum(u8) {
    bid = 0,
    ask = 1,
};

pub const Order = struct {
    order_id: u64, 
    price: f64, 
    quantity: u32, 
    side: Side, 
    timestamp: u64,    

    pub fn init(order_id: u64, price: f64, quantity: u32, side: Side, timestamp: u64) Order {
        return Order {
            .order_id = order_id,
            .price = price,
            .quantity = quantity,
            .side = side,
            .timestamp = timestamp,
        };
    }
};

// FIFO queue per price level
const OrderQueue = std.fifo.LinearFifo(Order, .Dynamic);

pub const OrderBook = struct {
    bids: Map(f64, OrderQueue),  // TODO: make descending price
    asks: Map(f64, OrderQueue),  // ascending price

    // sequence_number: u32 = 0,
    // last_trade_price: f32 = 0.0,
    // last_trade_size: u32 = 0,
    // best_bid: f32 = 0.0,
    // best_ask: f32 = 0.0,

    pub fn init(allocator: std.mem.Allocator) OrderBook {
        return OrderBook{
            .bids = Map(f64, OrderQueue).init(allocator), // TODO: make descending price possible
            .asks = Map(f64, OrderQueue).init(allocator),
        };
    }

    // pub fn deinit(self: *OrderBook) void {
    //     var it = self.bids.iterator();
    //     while (it.next()) |entry| {
    //         entry.value_ptr.*.deinit(); // deinit OrderQueue
    //     }
    //     self.bids.deinit();
    //
    //     it = self.asks.iterator();
    //     while (it.next()) |entry| {
    //         entry.value_ptr.*.deinit();
    //     }
    //     self.asks.deinit();
    // }
    
    pub fn addLimitOrder(self: *OrderBook, allocator: std.mem.Allocator, order: Order) !void {
        const book = switch (order.side) {
            .bid => &self.bids,
            .ask => &self.asks,
        };

        // Check if price level already exists
        if (book.contains(order.price)) {
            // Get pointer to existing queue and add order
            const queue_ptr = try book.getOrPut(order.price);
            try queue_ptr.writeItem(order);
        } else {
            // Create new queue, add order, then insert into map
            var new_queue = OrderQueue.init(allocator);
            try new_queue.writeItem(order);
            try book.insert(order.price, new_queue);
        }
    }

     pub fn popFrontAtPrice(self: *OrderBook, price: f64, side: Side) ?Order {
        const book = switch (side) {
            .bid => &self.bids,
            .ask => &self.asks,
        };
        
        if (!book.contains(price)) {
            return null;
        }
        
        const queue_ptr = book.getOrPut(price) catch return null;
        return queue_ptr.readItem();
    }   
};
