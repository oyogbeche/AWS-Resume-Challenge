const counter = document.querySelector(".counter_number");
async function updateCounter() {
    let response = await fetch("https://laii1mep7j.execute-api.eu-west-1.amazonaws.com/default/views");
    let data = await response.json()
    counter.innerHTML = `VIEWS: ${data}`;
}

updateCounter();