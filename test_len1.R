compute_ewma_simple <- function(values, alpha) {
  if (length(values) == 0) return(numeric(0))
  
  values <- as.numeric(values)
  if (length(values) == 0) return(numeric(0))
  
  values[is.na(values)] <- 0
  
  if (all(values == 0)) return(rep(0, length(values)))
  
  ewma <- numeric(length(values))
  
  if (is.na(values[1]) || is.null(values[1]) || !is.numeric(values[1])) {
    values[1] <- 0
  }
  
  ewma[1] <- values[1]
  
  # If length is 1, the loop doesn't run
  for (i in 2:length(values)) {
    val_i <- alpha * values[i]
    val_prev <- (1 - alpha) * ewma[i-1]
    ewma[i] <- val_i + val_prev
  }
  return(ewma)
}

# Test with length 1
values <- c(0.3382009)
alpha <- 0.1538
result <- compute_ewma_simple(values, alpha)
print(result)
