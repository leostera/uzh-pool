import { addCloseListener, icon, notifyUser, globalErrorMsg } from "./utils.js";

const errorClass = "error-message";
const notificationId = "filter-notification";

const form = document.getElementById("filter-form");

function isTextInput(ele) {
    let tagName = ele.tagName;
    if (tagName === "INPUT") {
        let validType = ['text', 'number', 'search'];
        let eleType = ele.type;
        return validType.includes(eleType);
    }
    return false;
}

const isListOperator = (operator) => {
    return ["contains_all", "contains_some", "contains_none"].includes(operator)
}

const disableValueInput = (o) => ["empty", "not_empty"].includes(o)

const isQueryKey = (key) => {
    return ["participation", "tag"].includes(key)
}

const findChildPredicates = (wrapper) => {
    return [...wrapper.querySelector(".predicate-wrapper").children].filter((elm) => elm.classList.contains("predicate"))
}

const addRequiredError = (elm) => {
    if (elm) {
        const wrapper = elm.closest(".form-group");
        [...wrapper.getElementsByClassName(errorClass)].forEach((elm) => elm.remove());
        let error = document.createElement("span");
        error.innerHTML = "This field is required."
        error.classList.add(errorClass, "help");
        wrapper.appendChild(error);
    }
}

// Should this update every time, the filter gets adjusted but not saved?
const updateContactCount = async () => {
    const target = document.getElementById("contact-counter");
    if (target) {
        const action = target.dataset.action;
        const spinner = icon(["icon-spinner-outline", "rotate"])
        target.appendChild(spinner);
        try {
            const response = await fetch(action);
            const data = await response.json();
            if (!response.ok) {
                throw (data.message || response.statusText || globalErrorMsg)
            }
            if (response.status < 200 || response.status > 300) {
                notifyUser(notificationId, "error", data.message)
            } else {
                target.innerHTML = data.count
            }
        } catch (error) {
            target.innerHTML = globalErrorMsg;
            notifyUser(notificationId, "error", error)
        };
    }
}

const predicateToJson = (outerPredicate, allowEmpty = false) => {
    const predicateType = outerPredicate.dataset.predicate;
    if (["or", "and"].includes(predicateType)) {
        const andOrPredicates = findChildPredicates(outerPredicate)
        return {
            [predicateType]: [...andOrPredicates].map((p) => predicateToJson(p, allowEmpty))
        }
    } else if (predicateType === "not") {
        const notPredicate = findChildPredicates(outerPredicate)[0];
        return {
            [predicateType]: predicateToJson(notPredicate, allowEmpty)
        }
    } else if (predicateType === "template") {
        let input = outerPredicate.querySelector('[name="template"]');
        if (!input.value && !allowEmpty) {
            addRequiredError(input)
        } else {
            const value = input.value || "";
            return {
                [predicateType]: value
            }
        }
    } else if (predicateType === "pred") {
        const toValue = (valueInput) => {
            let value = {}
            if (valueInput && valueInput.value) {
                var inputDataType = valueInput.dataset.inputType;
                switch (inputDataType) {
                    case "str":
                        value = {
                            [inputDataType]: valueInput.value
                        }
                        break;
                    case "nr":
                        value = {
                            [inputDataType]: parseFloat(valueInput.value)
                        }
                        break;
                    case "date":
                        value = {
                            [inputDataType]: valueInput.value
                        }
                        break;
                    case "bool":
                        value = {
                            [inputDataType]: (valueInput.value == "true")
                        }
                        break;
                    case "option":
                        value = {
                            [inputDataType]: valueInput.value
                        }
                        break;
                    case "language":
                        value = {
                            [inputDataType]: valueInput.value
                        }
                        break;
                    case "multi_select":
                        value = {
                            ["option"]: valueInput.value
                        }
                        break;
                    default:
                        value = {
                            ["str"]: valueInput.value
                        }
                }
            }
            return value
        }
        var error = false;
        const findElm = (attr) => outerPredicate.querySelector(`[name="${attr}"]`);
        var inputs = ["key", "operator"].map(findElm);
        let [key, operator] = inputs.map((input) => {
            if (!allowEmpty && !(input && input.value)) {
                error = true;
                addRequiredError(input);
            } else {
                return input ? input.value : null
            }
        })
        let value = null;
        let valueDisabled = disableValueInput(operator);
        if (!valueDisabled) {
            let isList = isListOperator(operator)
            if (isList) {
                var values = []
                if (isQueryKey(key)) {
                    values = [...outerPredicate.querySelectorAll(`[data-query="results"] [name="value[]"]:checked`)];
                } else {
                    values = [...outerPredicate.querySelectorAll(`[name="value[]"]:checked`)];
                }
                value = values.map(toValue)
            } else {
                const valueInput = findElm("value");
                if (!allowEmpty && !(valueInput && valueInput.value)) {
                    error = true;
                    addRequiredError(valueInput);
                } else {
                    value = toValue(valueInput)
                }
            }
        }

        if (!error) {
            let predicate = {
                "key": key,
                "operator": operator
            }
            if (value) {
                predicate.value = value;
            }
            return {
                [predicateType]: predicate
            }
        } else {
            notifyUser(notificationId, "error", "Please fill out all fields.")
            throw "Missing values";
        }
    } else {
        throw 'Unknown predicate type';
    }
}

function addRemovePredicateListener(element) {
    [...element.querySelectorAll("[data-delete-predicate]")].forEach(elm => {
        elm.addEventListener("click", (e) => {
            e.currentTarget.closest(".predicate").remove();
        })
    })
}


function addOperatorChangeListeners(wrapper) {
    [...wrapper.querySelectorAll("[name='operator']")].forEach((elm) => {
        elm.addEventListener("change", (e) => {
            const predicate = e.target.closest('.predicate');
            const inputs = [...predicate.querySelectorAll("[data-name='value[]'],[name='value'],[name='value[]']")];
            inputs.forEach(input => input.disabled = disableValueInput(e.currentTarget.value))
        })
    })
}

function configRequest(e, form) {
    if (isTextInput(e.srcElement) && !e.srcElement.value) {
        e.preventDefault()
    }
    const isPredicateType = e.detail.parameters.predicate;
    const allowEmpty = e.detail.parameters.allow_empty_values;
    const isSubmit = e.target.type === "submit"
    const isSearchForm = e.detail.elt.name === "search";
    const filterId = form.dataset.filter;
    if (filterId) {
        e.detail.parameters.filter = filterId;
    }

    if (isPredicateType || isSubmit || isSearchForm) {
        const elm = isSubmit ? form.querySelector(".predicate") : e.target.closest('.predicate');
        try {
            if (isSearchForm) {
                // Exclude currently selected experiments form query results
                var wrapper = e.detail.elt.closest("[data-query='wrapper']");
                var exclude = [...wrapper.querySelectorAll(`[data-query="results"] [name="value[]"]:checked`)].map(elt => elt.value);
                e.detail.parameters["exclude[]"] = exclude;
            } else {
                e.detail.parameters.query = predicateToJson(elm, allowEmpty);
            }
            // Only relevant when creating a filter template
            const title = document.querySelector('#filter-form [name="title"]');
            if (title && isSubmit) {
                if (!title.value) {
                    throw "Please add a title.";
                } else {
                    e.detail.parameters.title = title.value;
                }
            }
        } catch (error) {
            console.error(error)
            e.preventDefault();
            notifyUser(notificationId, "error", error)
        }
    }
    var event = new Event('submit');
    form.dispatchEvent(event);
}

export function initFilterForm() {
    if (form) {
        const submitButton = document.getElementById("submit-filter-form");
        submitButton.addEventListener('htmx:beforeSwap', (e) => {
            if (e.detail.xhr.status > 200 && e.detail.xhr.status < 300) {
                e.detail.shouldSwap = true;
            }
        })
        addRemovePredicateListener(form);
        addOperatorChangeListeners(form);
        form.addEventListener('htmx:afterSwap', (e) => {
            addRemovePredicateListener(e.detail.elt);
            addOperatorChangeListeners(e.detail.elt);
            if (e.detail.target.type === "submit") {
                updateContactCount();
            }
            addCloseListener(notificationId);
        })
        updateContactCount()
        form.addEventListener('htmx:configRequest', (e) => configRequest(e, form))
    }
}
