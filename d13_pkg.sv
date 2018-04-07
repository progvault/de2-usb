package d13_pkg;

   typedef struct packed {
      logic [15:0]       addr;
      logic [64:0][15:0] data; // bulk size + packet length
      logic [5:0]        words;
   } register_t;

   typedef struct packed {
      logic [64:0][15:0] data; // bulk size + packet length
      logic [5:0]        words;
   } oregister_t;

endpackage
