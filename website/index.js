function toggleMenu() {
    const navbar2 = document.querySelector(".navbar2");
    navbar2.classList.toggle("show");
}

const counter = document.querySelector(".counter_number");
async function updateCounter() {
    let response = await fetch("https://laii1mep7j.execute-api.eu-west-1.amazonaws.com/default/views");
    let data = await response.json()
    counter.innerHTML = `Views: ${data}`;
}
updateCounter();