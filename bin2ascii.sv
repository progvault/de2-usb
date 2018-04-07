module bin2ascii (
                // System Interface
                input         I_CLK,
                input         I_RSTF,
                // Binary to Hexadecimal
                input  [15:0] I_BIN,
                output [31:0] O_HEX
                );

   reg [7:0] hex0;
   reg [7:0] hex1;
   reg [7:0] hex2;
   reg [7:0] hex3;

   always @(posedge I_CLK or negedge I_RSTF)
     if (~I_RSTF) begin
        hex0 <= 8'h0;
        hex1 <= 8'h0;
        hex2 <= 8'h0;
        hex3 <= 8'h0;
     end
     else begin
        // byte 0
        case (I_BIN[3:0])        // ascii
          4'h0: hex0 <= 8'h30; //  '0'
          4'h1: hex0 <= 8'h31; //  '1'
          4'h2: hex0 <= 8'h32; //  '2'
          4'h3: hex0 <= 8'h33; //  '3'
          4'h4: hex0 <= 8'h34; //  '4'
          4'h5: hex0 <= 8'h35; //  '5'
          4'h6: hex0 <= 8'h36; //  '6'
          4'h7: hex0 <= 8'h37; //  '7'
          4'h8: hex0 <= 8'h38; //  '8'
          4'h9: hex0 <= 8'h39; //  '9'
          4'ha: hex0 <= 8'h61; //  'a'
          4'hb: hex0 <= 8'h62; //  'b'
          4'hc: hex0 <= 8'h63; //  'c'
          4'hd: hex0 <= 8'h64; //  'd'
          4'he: hex0 <= 8'h65; //  'e'
          4'hf: hex0 <= 8'h66; //  'f'
        endcase
        // byte 1
        case (I_BIN[7:4])        // ascii
          4'h0: hex1 <= 8'h30; //  '0'
          4'h1: hex1 <= 8'h31; //  '1'
          4'h2: hex1 <= 8'h32; //  '2'
          4'h3: hex1 <= 8'h33; //  '3'
          4'h4: hex1 <= 8'h34; //  '4'
          4'h5: hex1 <= 8'h35; //  '5'
          4'h6: hex1 <= 8'h36; //  '6'
          4'h7: hex1 <= 8'h37; //  '7'
          4'h8: hex1 <= 8'h38; //  '8'
          4'h9: hex1 <= 8'h39; //  '9'
          4'ha: hex1 <= 8'h61; //  'a'
          4'hb: hex1 <= 8'h62; //  'b'
          4'hc: hex1 <= 8'h63; //  'c'
          4'hd: hex1 <= 8'h64; //  'd'
          4'he: hex1 <= 8'h65; //  'e'
          4'hf: hex1 <= 8'h66; //  'f'
        endcase
        // byte 2
        case (I_BIN[11:8])       // ascii
          4'h0: hex2 <= 8'h30; //  '0'
          4'h1: hex2 <= 8'h31; //  '1'
          4'h2: hex2 <= 8'h32; //  '2'
          4'h3: hex2 <= 8'h33; //  '3'
          4'h4: hex2 <= 8'h34; //  '4'
          4'h5: hex2 <= 8'h35; //  '5'
          4'h6: hex2 <= 8'h36; //  '6'
          4'h7: hex2 <= 8'h37; //  '7'
          4'h8: hex2 <= 8'h38; //  '8'
          4'h9: hex2 <= 8'h39; //  '9'
          4'ha: hex2 <= 8'h61; //  'a'
          4'hb: hex2 <= 8'h62; //  'b'
          4'hc: hex2 <= 8'h63; //  'c'
          4'hd: hex2 <= 8'h64; //  'd'
          4'he: hex2 <= 8'h65; //  'e'
          4'hf: hex2 <= 8'h66; //  'f'
        endcase
        // byte 3
        case (I_BIN[15:12])      // ascii
          4'h0: hex3 <= 8'h30; //  '0'
          4'h1: hex3 <= 8'h31; //  '1'
          4'h2: hex3 <= 8'h32; //  '2'
          4'h3: hex3 <= 8'h33; //  '3'
          4'h4: hex3 <= 8'h34; //  '4'
          4'h5: hex3 <= 8'h35; //  '5'
          4'h6: hex3 <= 8'h36; //  '6'
          4'h7: hex3 <= 8'h37; //  '7'
          4'h8: hex3 <= 8'h38; //  '8'
          4'h9: hex3 <= 8'h39; //  '9'
          4'ha: hex3 <= 8'h61; //  'a'
          4'hb: hex3 <= 8'h62; //  'b'
          4'hc: hex3 <= 8'h63; //  'c'
          4'hd: hex3 <= 8'h64; //  'd'
          4'he: hex3 <= 8'h65; //  'e'
          4'hf: hex3 <= 8'h66; //  'f'
        endcase
     end

   assign O_HEX = {hex3, hex2, hex1, hex0};

endmodule    // bin2hex
