#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include </usr/include/libusb-1.0/libusb.h>

/* Specify VENDOR_ID and PRODUCT_ID for device */
#define VENDOR_ID   0x0471
#define PRODUCT_ID  0x3630

/* Define number of bytes to transfer */
#define EP_SIZE 64                       // bytes
#define TRANSFERS 1024*768*3/EP_SIZE     // number of transfers
#define TIMEOUT 10*1000                  // milliseconds

/* Use a global variable to keep the device handle */
static struct libusb_device_handle *handle = NULL;

/* count variables */
unsigned int count = 0;
unsigned int count_in = 0;
unsigned int count_out = 0;

/* The Endpoint addresses are hard-coded.  You should use libusb -v to find
 * the values corresponding to device
 */
static int ep_in  = 0x82;
static int ep_out = 0x01;

/* Write and Read buffers */
unsigned char wbuf[EP_SIZE*TRANSFERS];
unsigned char *wbuf_tmp;
unsigned char rbuf[EP_SIZE*TRANSFERS];
unsigned char rbuf_tmp[EP_SIZE*TRANSFERS];

static void LIBUSB_CALL xfr_cb_out(struct libusb_transfer *transfer )
{
  memcpy(wbuf+count_out*EP_SIZE, transfer->buffer, EP_SIZE);

  count_out++;  // one transfer complete
  if (count_out < TRANSFERS)
  {
    transfer->buffer = ++wbuf_tmp;
    libusb_submit_transfer(transfer);
  }
}

static void LIBUSB_CALL xfr_cb_in(struct libusb_transfer *transfer )
{
  int *completed = transfer->user_data;
  memcpy(rbuf+count_in*EP_SIZE, transfer->buffer, EP_SIZE);

  count_in++;  // one transfer complete
  if (count_in < TRANSFERS)
    libusb_submit_transfer(transfer);
  else
    *completed = 1;
}

int main(int argc, char **argv)
{
  const struct libusb_version *version;
  int completed = 0;
  size_t length = 64;
  int n;
  int rc;

  /* Get libusb version */
  version = libusb_get_version();
  fprintf(stderr, "libusb version: %d.%d.%d.%d\n", version->major, version->minor, version->micro, version->nano);

  /* Initialize libusb */
  rc = libusb_init(NULL);
  if (rc < 0)
  {
    fprintf(stderr, "Error Initializing libusb: %s\n", libusb_error_name(rc));
    exit(1);
  }

  /* Set debugging output to max level */
  libusb_set_debug(NULL, 3);

  /* Look for a specific device and open it */
  handle = libusb_open_device_with_vid_pid(NULL, VENDOR_ID, PRODUCT_ID);
  if (!handle)
  {
    fprintf(stderr, "Error finding USB device\n");
    goto out;
  }

  /* claim interface */
  rc = libusb_claim_interface(handle, 0);
  if (rc < 0)
  {
    fprintf(stderr, "Error claiming interface.\n");
    goto out;
  }

  /* allocate memory */
  wbuf_tmp = malloc(length*TRANSFERS);

  /* fill the buffer with incrementing data */
  for (n = 0; n < EP_SIZE*TRANSFERS; n++)
  {
    wbuf_tmp[n] = n;
  }

  struct libusb_transfer *transfer;
  transfer = libusb_alloc_transfer(0);
  libusb_fill_bulk_transfer(transfer, handle, ep_out, wbuf_tmp, EP_SIZE, xfr_cb_out, NULL, TIMEOUT);
  libusb_submit_transfer(transfer);

  transfer = libusb_alloc_transfer(0);
  libusb_fill_bulk_transfer(transfer, handle, ep_in, rbuf_tmp, EP_SIZE, xfr_cb_in, &completed, TIMEOUT);
  libusb_submit_transfer(transfer);

  /* Handle Events */
  while (!completed)
  {
    rc = libusb_handle_events_completed(NULL, &completed);
    if (rc != LIBUSB_SUCCESS)
    {
      fprintf(stderr, "Transfer Error: %s\n", libusb_error_name(rc));
      break;
    }
  }

  fprintf(stderr, "completed\n");

  int res;
  res = memcmp(rbuf, wbuf, sizeof(wbuf));
  if (res != 0)
    fprintf(stderr, "miscompare\n");
  else
    fprintf(stderr, "success\n");

  //* Release the interface */
  libusb_release_interface(handle, 0);

  /* Close the device handle */
  if (handle)
    libusb_close(handle);

out:
  if (handle)
  {
    libusb_close(handle);
  }
  libusb_exit(NULL);

  return rc;
}
