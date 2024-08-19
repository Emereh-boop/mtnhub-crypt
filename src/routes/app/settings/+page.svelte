<script lang="ts">
  import { onMount } from "svelte";
  import SettingsLayout from "./+layout.svelte";
  let errorMsg: string | null = null;
  let successMsg: string | null = null;
  let show2g = false;
  let show5g = false;
  let modalOpen = false;
  let wifiData: Array<any> | null = [];
  let progress= Number<any> = 10

  const saveChanges = async (event: any) => {
    event.preventDefault();
    errorMsg = null;
    successMsg = null;
    const formData = new FormData(event.target);
    let deviceName = "2.4G";
    let oldSsid = wifiData[0].ssid;
    let oldKey = wifiData[0].wpapsk;
    let oldAuthmode = wifiData[0].authmode;
    if (event.target.id === "wifiForm5g") {
      deviceName = "5G";
      oldSsid = wifiData[1].ssid;
      oldKey = wifiData[1].wpapsk;
      oldAuthmode = wifiData[1].authmode;
    }
    if (formData.get("ssid") !== oldSsid) {
      try {
        const response = await fetch(
          "http://192.168.0.1:8080/cgi-bin/api.cgi",
          {
            method: "POST",
            credentials: "include",
            headers: {
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              cmd: "change_ssid",
              devname: deviceName,
              newssid: formData.get("ssid"),
            }),
          },
        );
        const resp = await response.json();
        if (resp.success) {
          successMsg = "SSID changed successfully";
          setTimeout(() => {
          successMsg = null;
        }, 3000)
        } else {
          errorMsg = "Failed to save changes";
          setTimeout(() => {
          errorMsg = null;
        }, 3000)
        }
      } catch (e) {
        errorMsg = "Failed to save changes";
        setTimeout(() => {
          errorMsg = null;
        }, 3000)
      }
    }
    if (
      formData.get("key") !== oldKey ||
      formData.get("security") !== oldAuthmode
    ) {
      try {
        const response = await fetch(
          "http://192.168.0.1:8080/cgi-bin/api.cgi",
          {
            method: "POST",
            credentials: "include",
            headers: {
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              cmd: "change_wireless_key",
              devname: deviceName,
              newkey:
                formData.get("key") !== oldKey ? formData.get("key") : null,
              authmode:
                formData.get("auth") !== oldAuthmode
                  ? formData.get("auth") === "WPA2PSK"
                    ? 2
                    : 0
                  : null,
            }),
          },
        );
        const resp = await response.json();
        if (resp.success) {
          successMsg = "Key changed successfully";
        } else {
          errorMsg = "Failed to save changes";
          setTimeout(() => {
          errorMsg = null;
        }, 3000)
        }
      } catch (e) {
        errorMsg = "Failed to save changes";
        setTimeout(() => {
          errorMsg = null;
        }, 3000)
      }
    }
  };

  const fetchWifis = async () => {
    try {
      const response = await fetch("http://192.168.0.1:8080/cgi-bin/api.cgi", {
        method: "POST",
        credentials: "include",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          cmd: "wifis",
        }),
      });
      const resp = await response.text();
      const jsonPart = resp.substring(resp.indexOf("{"));
      const json = JSON.parse(jsonPart);
      wifiData = json.data;
    } catch (e) {}
  };

  const reset = async (event: any) => {
    event.preventDefault()
    errorMsg = null;
    successMsg = null;
    modalOpen = false;
    try {
      const response = await fetch("http://192.168.0.1:8080/cgi-bin/api.cgi", {
        method: "POST",
        credentials: "include",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          cmd: "reset",
        }),
      });
      const resp = await response.json();
      if (resp.success) {
          successMsg = "Your device has been reset successfully";
          setTimeout(() => {
          successMsg = null;
        }, 3000)
        } else {
          errorMsg = "Failed to reset device";
          setTimeout(() => {
          errorMsg = null;
        }, 3000)
        }
    } catch {
      errorMsg = "an error occured"
      setTimeout(() => {
          errorMsg = null;
        }, 3000)
    }
  };
  
  function validateInput(event) {
            const input = event.target.value;
            const regex = /^[a-zA-Z0-9:_]*$/;
            if (!regex.test(input)) {
                event.target.value = input.slice(0, -1);
                // alert("Only a-z, A-Z, 0-9, :, and _ characters are allowed.");
            }
        }

  onMount(() => {
    fetchWifis();
  });
</script>

<SettingsLayout>
  <div class="lg:grid lg:grid-cols-12 container mx-auto">
    <div class="flex col-span-2 items-start justify-center p-[35.5px]">
      <a href="#/myhub" class=" my-[4px] gap-[12px] ml-3 flex"
        ><img
          src="/backArrowIcon.svg"
          class="w-[12.41px] ml-[7px]"
          alt="view-all-connected-devices-icon"
        />Previous
      </a>
    </div>
    <div class="lg:col-span-8 p-[39px] border shadow-xl min-h-[420px]">
      {#if errorMsg}
        <div
          class="border-peach-400 mb-[16px] bg-peach-100 w-full sm:w-4/5 lg:w-3/5 rounded-[4px] p-4 border flex items-center"
        >
          <img src="/info-red.svg" class=" col-span-1 mr-4" alt="" />
          <p class="text-gray-400 col-span-4">{errorMsg}</p>
        </div>
      {/if}
      {#if successMsg}
        <div
          class="border-black mb-[16px] w-full sm:w-4/5 lg:w-3/5 rounded-[4px] p-4 border flex items-center"
        >
          <img src="/info-icon.svg" class=" col-span-1 mr-4" alt="" />
          <p class="text-gray-400 col-span-4">{successMsg}</p>
        </div>
      {/if}
      <div class="col-span-2 flex flex-col">
        <span class="col-span-full text-[18px] font-bold text-black"
          >Hub Properties</span
        >
        <span class="text=[13px] text-gray-400 font-[400]"
          >Manage your hub properties</span
        >
      </div>
      <div class="w-full max-w-[450px]">
        <form on:submit={saveChanges} id="wifiForm2g">
          <!-- SSID  -->
          <div class="flex flex-col justify-between">
            <div
              class="flex items-center gap-[12px] justify-between mb-[20px] mt-[30px]"
            >
              <label
                for="ssid2g"
                class="text-gray-400 text-[13px] w-[1/4] flex items-center gap-[3px]"
                >WiFi Name (SSID): <img
                  src="/question-circle.svg"
                  alt=""
                  class="w-[16px] h-[16px]"
                /></label
              >
              <input
                type="text"
                id="ssid2g"
                name="ssid"
                placeholder="WiFi Name"
                on:input={(event) => validateInput(event)}
                value={wifiData[0]?.ssid}
                required
                minlength="1"
                class="flex-1 font-mono text-gray-400 h-[35px] border rounded-[16px] border-gray-100 focus:border-primary focus:outline-none hover:border-primary px-[19px]"
              />
            </div>
            <!-- Security Mode  -->
            <div class="flex items-center mb-[20px]">
              <label
                for="security2g"
                class="text-gray-400 w-[141px] items-center flex gap-[3px]"
                >Security Mode: <img src="/question-circle.svg" alt="" /></label
              >
              <select
                id="auth2g"
                name="auth"
                value={wifiData[0]?.authmode}
                class="flex-1 font-mono text-gray-400 focus:outline-none h-[35px] border rounded-[16px] border-gray-100 focus-visible:border-primary active:border-primary hover:border-primary px-[19px]"
              >
                <option value="OPEN">OPEN</option>
                <option value="WPA2PSK">WPA2PSK</option>
              </select>
            </div>
            <!-- Password  -->
            <div class="flex items-center mb-[20px]">
              <label for="key2g" class="text-gray-400 w-[141px]"
                >WiFi Password:
              </label>
              <input
                type={show2g ? "text" : "password"}
                id="key2g"
                name="key"
                placeholder="******"
                disabled={wifiData[0]?.authmode !== "WPA2PSK"}
                required
                value={wifiData[0]?.wpapsk}
                minlength="8"
                class="flex-1 font-mono text-gray-400 h-[35px] border rounded-[16px] border-gray-100 focus:border-primary focus:outline-none hover:border-primary px-[19px]"
              />
            </div>
            <!-- Show password -->
            <div class="flex items-center mb-[20px]">
              <label for="show2g" class="text-gray-400 w-[141px] flex-none"
              ></label>
              <input
                type="checkbox"
                id="show2g"
                name="show2g"
                class="h-[17px] w-[17px] rounded-sm before:content[''] peer relative cursor-pointer appearance-none border border-primary transition-all before:absolute before:top-2/4 before:left-2/4 before:block before:h-12 before:w-12 before:-translate-y-2/4 before:-translate-x-2/4 before:rounded-full before:bg-primary before:opacity-0 before:transition-opacity checked:border-primary checked:bg-primary checked:before:bg-primary hover:before:opacity-10"
                disabled={wifiData[0]?.authmode !== "WPA2PSK"}
                on:click={() => (show2g = !show2g)}
              />
              <label for="show" class="text-gray-400 ml-[10px]"
                >Show Password</label
              >
            </div>
          </div>

          <!-- Save Change -->
          <button
            type="submit"
            class="ml-[141px] text-[14px] px-6 bg-primary text-white h-[35px] rounded-[20px]"
          >
            Save Changes
          </button>
        </form>
      </div>
      <hr class="my-10 h-[1px] border-none bg-[#c4c4c4]" />
      <div class="w-full max-w-[450px]">
        <form on:submit={saveChanges} id="wifiForm5g">
          <!-- SSID  -->
          <div class="flex flex-col justify-between">
            <div
              class="flex items-center gap-[12px] justify-between mb-[20px] mt-[30px]"
            >
              <label
                for="ssid5g"
                class="text-gray-400 text-[13px] w-[1/4] flex items-center gap-[3px]"
                >WiFi Name (SSID): <img
                  src="/question-circle.svg"
                  alt=""
                  class="w-[16px] h-[16px]"
                /></label
              >
              <input
                type="text"
                id="ssid5g"
                name="ssid"
                placeholder="WiFi Name"
                on:input={(event) => validateInput(event)}
                value={wifiData[1]?.ssid}
                required
                minlength="1"
                class="flex-1 font-mono w-[239px] text-gray-400 h-[35px] border rounded-[16px] border-gray-100 focus:border-primary focus:outline-none hover:border-primary px-[19px]"
              />
            </div>
            <!-- Security Mode  -->
            <div class="flex items-center mb-[20px]">
              <label
                for="security5g"
                class="text-gray-400 w-[141px] items-center flex gap-[3px]"
                >Security Mode: <img src="/question-circle.svg" alt="" /></label
              >
              <select
                id="auth5g"
                name="auth"
                value={wifiData[1]?.authmode}
                class="flex-1 font-mono text-gray-400 focus:outline-none h-[35px] border rounded-[16px] border-gray-100 focus-visible:border-primary active:border-primary hover:border-primary px-[19px]"
              >
                <option value="OPEN">OPEN</option>
                <option value="WPA2PSK">WPA2PSK</option>
              </select>
            </div>
            <!-- Password  -->
            <div class="flex items-center mb-[20px]">
              <label for="key5g" class="text-gray-400 w-[141px]"
                >WiFi Password:
              </label>
              <input
                type={show5g ? "text" : "password"}
                id="key5g"
                name="key"
                placeholder="******"
                disabled={wifiData[1]?.authmode !== "WPA2PSK"}
                required
                value={wifiData[1]?.wpapsk}
                minlength="8"
                class="flex-1 font-mono text-gray-400 h-[35px] border rounded-[16px] border-gray-100 focus:border-primary focus:outline-none hover:border-primary px-[19px]"
              />
            </div>
            <!-- Show password -->
            <div class="flex items-center mb-[20px]">
              <label for="show5g" class="text-gray-400 w-[141px] flex-none"
              ></label>
              <input
                type="checkbox"
                id="show5g"
                name="show5g"
                class="h-[17px] w-[17px] rounded-sm before:content[''] peer relative cursor-pointer appearance-none border border-primary transition-all before:absolute before:top-2/4 before:left-2/4 before:block before:h-12 before:w-12 before:-translate-y-2/4 before:-translate-x-2/4 before:rounded-full before:bg-primary before:opacity-0 before:transition-opacity checked:border-primary checked:bg-primary checked:before:bg-primary hover:before:opacity-10"
                disabled={wifiData[1]?.authmode !== "WPA2PSK"}
                on:click={() => (show5g = !show5g)}
              />
              <label for="show5g" class="text-gray-400 ml-[10px]"
                >Show Password</label
              >
            </div>
          </div>

          <!-- Save Change -->
          <button
            type="submit"
            class="ml-[141px] text-[14px] px-6 bg-primary text-white h-[35px] rounded-[20px]"
          >
            Save Changes
          </button>
        </form>
      </div>
      <hr class="my-10 h-[1px] border-none bg-[#c4c4c4]" />
      <div class="flex flex-col justify-between h-[209px]">
        <div class="col-span-2 flex flex-col">
          <span class="col-span-full text-[18px] font-bold text-black"
            >System Update</span
          >
          <span class="text=[13px] text-gray-400 font-[400]"
            >Check and download the latest system update</span
          >
        </div>
        <div class="h-[121px] flex flex-col justify-between">
          <div class="flex items-center">
            <img src="/Logomark.svg" alt="" class="w-[32px] h-[32px]" />
            <p class="font-[700] text-[14px] text-[#1d1d1d]">Wicrypt OS</p>
          </div>
          <hr />
          <div
            class="text-[12px] text-[#6b6b6b] font-[400] flex flex-col md:flex-row items-center justify-between"
          >
            <p>Firmware Version Version 2.0093 | Build 43344</p>
            <div class="">
              <button
                type="submit"
                class="ml-[141px] text-[12px] px-6 bg-primary text-white h-[35px] rounded-[20px]"
              >
                Download Update
              </button>
              <button
                type="button"
                class="text-[12px] px-6 bg-primary text-white h-[35px] rounded-[20px]"
                on:click={() => {
                  modalOpen = true;
                }}
              >
                Reset
              </button>
            </div>
          </div>
          <hr />
        </div>
      </div>
      {#if modalOpen}
        <div
          class="modal z-50 fixed w-full h-full top-0 left-0 flex items-center justify-center p-8 lg:p-0"
        >
          <div
            class="modal-overlay fixed w-full h-full bg-gray-900 opacity-50"
          ></div>
          <div
            class="bg-white w-full lg:h-max lg:w-1/5 mx-auto rounded-lg shadow-xl z-50 overflow-y-auto"
          >
            <!-- Modal content goes here -->
            <div
              class="head text-center bg-primary py-5 px-8 text-2xl font-extrabold"
            >
              <!-- Modal header -->
              Reset
            </div>
            <div class="content p-8">
              <!-- Modal body -->
              <form method="POST" on:submit={reset}>
                <div class="flex flex-col align-middle text-center">
                  <div class="w-full mb-4">
                    Are you sure you want to continue ?
                  </div>
                  <div class=" w-full flex gap-4 justify-center">
                    <button
                      type="submit"
                      class="text-[12px] px-6 bg-primary text-white h-[35px] rounded-[20px]"
                    >
                      Yes
                    </button>
                    <button
                      type="button"
                      class="text-[12px] px-6 border-primary border text-primary h-[35px] rounded-[20px]"
                      on:click={() => {
                        modalOpen = false;
                      }}
                    >
                      cancel
                    </button>
                  </div>
                </div>
              </form>
            </div>
          </div>
        </div>
      {/if}
      {#if !show5g}
        <div class="h-[141px] rounded-[20px]"></div>
        <!-- <div class="grid grid-cols-3 md:grid-cols-12 mt-6">
          <div
            class="col-span-3 md:col-span-10 relative h-4 bg-primary/20 rounded-full"
          >
            <div
              class="absolute h-full bg-primary rounded-full"
              style="width: {progress}%;"
            ></div>
            <span
              class="absolute inset-0 flex items-center justify-center text-gray-400 font-bold text-[14px]"
              >Setting up...</span
            >
          </div>
          <span
            class=" hidden md:block pl-3 md:col-span-2 font-normal text-[14px] text-primary"
            >{progress}%</span
          >
        </div> -->
      {/if}
    </div>
    <!-- <div class="lg:col-span-2"></div> -->
  </div>
</SettingsLayout>
