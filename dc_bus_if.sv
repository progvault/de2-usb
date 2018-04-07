import d13_pkg::*;

module dc_bus_if (
                  // System Interface
                  input               I_CLK,      // Clock 50 MHz
                  input               I_RSTF,     // Reset (active low)
                  // Bus Interface
                  output [ 1:0]       O_DC_ADDR,  // Address Bus, [1] = PIO bus of HC(=0) or DC(=1), [0] = command(=1) or data(=0) port
                  output              O_DC_CSF,   // Chip Select
                  output              O_DC_RDF,   // Read Strobe
                  output              O_DC_WRF,   // Write Strobe
                  inout  [15:0]       IO_DC_DATA, // Data Bus (bidir)
                  input               I_DC_INT1,  // Interrupt 1, from Device Controller
                  // Bus Interface Control
                  input               I_START,    // Start transfer on Bus Interface
                  input               I_WRITE,    // Write data on Bus Interface
                  input               I_READ,     // Read data on Bus Interface
                  input               I_DWORD,    // Read double-word register
                  input               I_BURST,    // Burst transfer enable
                  input  [ 5:0]       I_WORDS,    // Burst transfer number of words (max 64 bytes)
                  input  [ 7:0]       I_ADDR,     // Address to write to Bus Interface
                  input  [31:0]       I_WDATA,    // Data to write to Bus Interface
                  output [31:0]       O_RDATA,    // Data read from Bus Interface
                  input  [64:0][15:0] I_WBUFF,    // Data to write to Bust Interface
                  output [64:0][15:0] O_RBUFF,    // Data read from Bust Interface Read Buffer
                  input  register_t   I_REGISTER,
                  output oregister_t  O_REGISTER,
                  output              O_DONE      // Done with current task
                  );

`include "d13_parameters.svh"

   parameter TCYC = 15; // CSF high to CSF low cycle time (>205ns, 15=~320ns)
   parameter TLOW = 3;  // Chip Select low time           (>25ns,  ~80ns)

   register_t r;

   logic [64:0][15:0] rbuff;
   logic [64:0][15:0] wbuff;

   reg addr0;
   reg csn;
   reg rdn;
   reg wrn;
   reg dout;
   reg start;
   reg done;
   reg [15:0] wdata;
   reg [15:0] rdata16;
   reg [31:0] rdata32;
   reg [ 3:0] dcnt;
   reg [ 5:0] cnt;

   typedef enum {IDLE, CMD, RD0, RD1, RD, WR0, WR1, WR, TDLY, DONE} bus_trans_t;
   bus_trans_t st; // state
   bus_trans_t rt; // return state

   always_ff @(posedge I_CLK or negedge I_RSTF)
     if (~I_RSTF) begin
        start <= 0;
     end
     else begin
        start <= I_START;
     end

   always_ff @(posedge I_CLK or negedge I_RSTF)
     if (~I_RSTF) begin
        st      <= IDLE;
        addr0   <= 0;
        csn     <= 1;
        rdn     <= 1;
        wrn     <= 1;
        dout    <= 0;
        wdata   <= 0;
        rdata16 <= 0;
        rdata32 <= 0;
        rbuff   <= 0;
        wbuff   <= 0;
        dcnt    <= 0;
        cnt     <= 0;
        r       <= 0;
        done    <= 0;
     end
     else begin

        // defaults
        addr0 <= 0;
        csn   <= 1;
        rdn   <= 1;
        wrn   <= 1;
        dout  <= 0;
        dcnt  <= dcnt + 1;
        done  <= 0;
        case(st)
          IDLE: begin
             dcnt  <= 0;
             if ({start, I_START} == 2'b01) begin // rising edge
                st <= CMD;
             end
          end
          CMD: begin
             addr0 <= 1;
             csn   <= 0;
             dout  <= 1;
             wdata <= I_REGISTER.addr;
             if (dcnt < TLOW) begin
                wrn <= 0;
             end
             else if (dcnt == TLOW) begin
                dcnt <= 0;
                st   <= TDLY;
                if (I_REGISTER.words == 0)
                  rt <= DONE;
                else if (I_READ)
                  rt <= RD;
                else if (I_WRITE)
                  rt <= WR;
                else
                  rt <= DONE;
             end
          end
          RD: begin
             csn            <= 0;
             if (dcnt < TLOW) begin
                rdn         <= 0;
                r.data[cnt] <= IO_DC_DATA;
             end
             else if (dcnt == TLOW) begin
                st   <= TDLY;
                if (cnt == I_REGISTER.words-1) begin
                   cnt  <= 0;
                   rt   <= DONE;
                end
                else begin
                   cnt  <= cnt + 1;
                   rt   <= RD;
                end
             end
          end
          WR: begin
             csn    <= 0;
             dout   <= 1;
             wdata  <= I_REGISTER.data[cnt];
             if (dcnt < TLOW) begin
                wrn <= 0;
             end
             else if (dcnt == TLOW) begin
                st   <= TDLY;
                if (cnt == I_REGISTER.words-1) begin
                   cnt  <= 0;
                   rt   <= DONE;
                end
                else begin
                   cnt  <= cnt + 1;
                   rt   <= WR;
                end
             end
          end
          DONE: begin
             dcnt <= 0;
             done <= 1'b1;
             st   <= IDLE;
          end
          TDLY: begin
             if (dcnt == TCYC) begin
                st <= rt;
             end
          end
        endcase
     end

   assign O_DC_ADDR    = {1'b1, addr0};         // PIO bus of Device Controller is selected
   assign O_DC_CSF     = csn;
   assign O_DC_RDF     = rdn;
   assign O_DC_WRF     = wrn;
   assign IO_DC_DATA   = dout ? wdata : 16'hZZZZ;
   assign O_RDATA      = r.data[1:0];
   assign O_RBUFF      = rbuff;
   assign O_REGISTER   = r;
   assign O_DONE       = done;

endmodule // dc_bus_if
