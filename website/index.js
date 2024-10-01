const counter = document.querySelector(".counter_number");
async function updateCounter() {
    let response = await fetch("https://436z7fqyzmsspkjc3c3772dwnu0ssmvv.lambda-url.eu-west-1.on.aws/");
    let data = await response.json()
    counter.innerHTML = `VIEWS: ${data}`;
}

updateCounter();