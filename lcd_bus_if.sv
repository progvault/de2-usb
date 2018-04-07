module lcd_bus_if (
                   // System Interface
                   input             I_CLK,
                   input             I_RSTF,
                   output            O_LCD_ON,
                   // LCD Bus Interface
                   output            O_LCD_EN,
                   output            O_LCD_RS,    // Register select, 0 = Command, 1 = Data
                   output            O_LCD_RWF,   // Read Write select, 0 = Write, 1 = Read
                   output [7:0]      O_LCD_DATA,
                   // LCD Interface Control
                   input             I_START,
                   input [0:15][7:0] I_WDATA0,
                   input [0:15][7:0] I_WDATA1,
                   output            O_DONE
                   );

   // Commands:
   // 0x38 = function set, 8-bit operation, 2-line display, 5x8 dot character font
   // 0x0F = display on, entire display on, cursor on, blinking
   // 0x01 = display clear, clears entire display and sets DDRAM address 0 in address counter
   // 0x06 = entry mode set, increment cursor, do not shift screen
   const logic [0:6][7:0] icode = {8'h38, 8'h38, 8'h38, 8'h38, 8'h0F, 8'h01, 8'h06};


   parameter  TDLY    = {12{1'b1}};  // ~82 us delay
   parameter  FSET_TC = 6;           // function set terminal count (6)
   parameter  BYTE_TC = {4{1'b1}};   // byte terminal count (16), 4-bits of all ones

   typedef enum {IDLE, INIT, WAIT_START, LINE0, WRITE0, LINE1, WRITE1, DONE} bus_trans_t;
   bus_trans_t st;

   reg        wdone;
   reg        edone, edone1, edone_re;
   reg        done;
   reg [21:0] wcnt;     // wait delay (>40 ms)
   reg [11:0] dcnt;     // instruction delay (~82 us)
   reg [ 5:0] ecnt;     // enable delay (~1us)
   reg [ 2:0] fcnt;     // function set count
   reg [ 3:0] bcnt;     // byte count
   reg        ecnt_ld;
   reg        ecnt_en;
   reg        lcd_en1, lcd_en2;
   reg        lcd_rs;
   reg        lcd_rwf;
   reg [ 7:0] lcd_data;

   // intialization wait (>40 ms after a POR or system reset)
   always @ (posedge I_CLK or negedge I_RSTF)
     if (~I_RSTF) begin
        wdone <= 0;
        wcnt  <= 0;
     end
     else begin
        if (wcnt[21])
          wdone <= 1;
        else
          wcnt  <= wcnt + 1;
     end

   // enable cycle (>1us)
   always @ (posedge I_CLK or negedge I_RSTF)
     if (~I_RSTF) begin
        edone    <= 0;
        edone1   <= 0;
        edone_re <= 0;
        ecnt     <= '1;
        lcd_en1  <= 1;
        lcd_en2  <= 1;
     end
     else begin

        //default
        edone <= 0;

        // enable counter
        if (ecnt_ld || ~wdone)
           ecnt  <= '1;
        else if (ecnt == 0)
           edone <= 1;  // enable cycle done
        else if (ecnt_en)
           ecnt  <= ecnt - 1;

        // rising edge detect
        edone1   <= edone;
        edone_re <= !edone1 & edone;

        // lcd_en
        lcd_en1 <= ecnt[5];
        lcd_en2 <= lcd_en1; // 2T delay (total), to meet address setup time
     end

   // state machine for initialization
   always @ (posedge I_CLK or negedge I_RSTF)
     if (~I_RSTF) begin
        ecnt_ld  <= 0;
        ecnt_en  <= 0;
        lcd_rs   <= 0;
        lcd_rwf  <= 1;
        lcd_data <= 0;
        dcnt     <= 0;
        fcnt     <= 0;
        bcnt     <= 0;
        done     <= 0;
        st       <= IDLE;
     end
     else begin

        ecnt_en  <= 0;
        ecnt_ld  <= 0;
        lcd_rwf  <= 0;
        dcnt     <= 0;
        done     <= 0;

        case (st)
          IDLE: begin
             if (wdone) begin
                st <= INIT;
             end
          end
          INIT: begin
             lcd_rs   <= 0;
             lcd_data <= icode[fcnt];
             ecnt_en  <= 1;
             dcnt     <= dcnt + 1;
             if (dcnt == TDLY) begin
                ecnt_ld <= 1;
                fcnt <= fcnt + 1;
                if (fcnt == FSET_TC)
                  st <= DONE;
             end
          end
          WAIT_START: begin
             if (I_START)
               st <= LINE0;
          end
          LINE0: begin
             lcd_rs   <= 0;
             lcd_data <= 8'h80;
             ecnt_en  <= 1;
             dcnt     <= dcnt + 1;
             if (dcnt == TDLY) begin
                ecnt_ld <= 1;
                st <= WRITE0;
             end
          end
          WRITE0: begin
             lcd_rs   <= 1;
             lcd_data <= I_WDATA0[bcnt];
             ecnt_en  <= 1;
             dcnt     <= dcnt + 1;
             if (dcnt == TDLY) begin
                ecnt_ld <= 1;
                bcnt    <= bcnt + 1;
                if (bcnt == BYTE_TC)
                  st <= LINE1;
             end
          end
          LINE1: begin
             lcd_rs   <= 0;
             lcd_data <= 8'hC0;
             ecnt_en  <= 1;
             dcnt     <= dcnt + 1;
             if (dcnt == TDLY) begin
                ecnt_ld <= 1;
                st <= WRITE1;
             end
          end
          WRITE1: begin
             lcd_rs   <= 1;
             lcd_data <= I_WDATA1[bcnt];
             ecnt_en  <= 1;
             dcnt     <= dcnt + 1;
             if (dcnt == TDLY) begin
                ecnt_ld <= 1;
                bcnt <= bcnt + 1;
                if (bcnt == BYTE_TC)
                  st <= DONE;
             end
          end
          DONE: begin
             done <= 1;
             st   <= WAIT_START;
          end
        endcase
     end

   assign O_LCD_ON   = 1;
   assign O_LCD_EN   = lcd_en2;
   assign O_LCD_RS   = lcd_rs;
   assign O_LCD_RWF  = lcd_rwf;
   assign O_LCD_DATA = lcd_data;
   assign O_DONE     = done;

endmodule // lcd_bus_if
